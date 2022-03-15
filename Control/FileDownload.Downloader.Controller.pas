{
  *********************************
  (C)riado por Magno Lima 2022
  Classe para Downloader

  Uso:
  - Criar o objeto TDownloadFile
  - Atribuir lista de arquivos na propriedade FilesToDownload
  - Atribuir pasta para salvar arquivos
  - Iniciar download chamando StartDownload
  - Usar Abort para interromper

  *********************************
}
{ .$DEFINE USING_ATTACHMENT }
unit FileDownload.Downloader.Controller;

interface

uses
  System.Classes, System.Types, System.SysUtils, System.IOUtils,
  System.Generics.Collections, System.Threading, System.Net.URLClient, System.Net.HttpClient,
  System.Net.HttpClientComponent, Vcl.ComCtrls,
  FileDownload.Common.Controller;

const
  FILE_NOT_FOUND = 404;

type
  TDownloadErrorLevel = (dlHasFile, dlNoFiles, dlInvalidUrl);
  TDownloadStatus = (dsNone, dsNotFound, dsDownloading, dsDone, dsFinished, dsError, dsAborted);

type
  TDownloadFile = class(TObject)
  private
    FHttpEngine: TNetHTTPClient;
    FObservers: TList;
    FPosition: Integer;
    FFileStream: TFileStream;
    FHasContent: Boolean;
    FFileName: String;
    FTemporaryFileName: String;
    FDownloadDirectory: String;
    FFilesToDownload: TStringDynArray;
    FIsDownloading: Boolean;
    FErrorLevel: TDownloadErrorLevel;
    FDownloadStatus: TDownloadStatus;
    FTotalFilesInQueue: Integer;
    LinkDownloader: TThread;
    procedure OnRequestCompleted(const Sender: TObject; const AResponse: IHTTPResponse);
    procedure ClearList;
    procedure setFilesToDownload(const Value: TStringDynArray);
    function HasFileToDownload: TDownloadErrorLevel;
    procedure DownloadFiles;
    // Caso o nome do arquivo venha em Attachment, podemos usar o processo abaixo para obtê-lo
{$IFDEF USING_ATTACHMENT}
    function ExtractAttachmentFileName(NetHeaders: TNetHeaders): String;
{$ENDIF}
    procedure InitializeDownloader;
    procedure ClientRequestError(const Sender: TObject; const AError: string);
  public
    FFileInQueue: Integer;
    constructor Create(AOwner: TComponent);
    Destructor Destroy; override;
    procedure StartDownload;
    procedure Abort;
    procedure OnReceiveData(const Sender: TObject; AContentLength, AReadCount: Int64; var Abort: Boolean);
    property FilesToDownload: TStringDynArray read FFilesToDownload write setFilesToDownload;
    property Position: Integer read FPosition;
    property IsDownloading: Boolean read FIsDownloading;
    property DownloadFolder: String read FDownloadDirectory write FDownloadDirectory;
    property FileName: String read FFileName;
    property TotalFilesInQueue: Integer read FTotalFilesInQueue;
    property FileInQueue: Integer read FFileInQueue;
    property Status: TDownloadStatus read FDownloadStatus;
    property ErrorLevel: TDownloadErrorLevel read FErrorLevel;
  end;

implementation

{ TDownloadFile }

constructor TDownloadFile.Create(AOwner: TComponent);
begin
  FDownloadDirectory := '.\';
  FHttpEngine := TNetHTTPClient.Create(AOwner);
  FHttpEngine.OnReceiveData := OnReceiveData;
  FHttpEngine.OnRequestError := ClientRequestError;
  FHttpEngine.OnRequestCompleted := OnRequestCompleted;
end;

destructor TDownloadFile.Destroy;
begin
  if Assigned(FFileStream) then
    FFileStream.Free;
  FHttpEngine.Free;
  inherited;
end;

procedure TDownloadFile.ClientRequestError(const Sender: TObject; const AError: string);
begin
  FDownloadStatus := TDownloadStatus.dsError;
end;

procedure TDownloadFile.Abort;
begin
  if not Assigned(LinkDownloader) then
    Exit;
  if LinkDownloader.Started then
    LinkDownloader.Terminate;
  Self.ClearList;
  FIsDownloading := False;
  FDownloadStatus := TDownloadStatus.dsAborted;
end;

procedure TDownloadFile.ClearList;
begin
  FilesToDownload := nil;
end;

// Caso o nome do arquivo venha em Attachment, podemos usar o processo abaixo para obtê - lo como o nome
// do arquivo já está especificado na Url, esta linha não é necessária
{$IFDEF USING_ATTACHMENT}

function TDownloadFile.ExtractAttachmentFileName(NetHeaders: TNetHeaders): String;
var
  I: Integer; // that's the law!

  function Extract(Value: String): String;
  var
    TheChar: Char;
    start: Boolean;
  begin
    Result := '';
    start := False;
    for TheChar in Value do
    begin
      if TheChar = '"' then
        start := not start;
      if (TheChar <> '"') and start then
        Result := Result + TheChar;
    end;
  end;

begin
  for I := 0 to High(NetHeaders) do
  begin
    if NetHeaders[I].Value.Contains('attachment;') then
    begin
      Result := Extract(NetHeaders[I].Value);
      Break;
    end;
  end;
end;
{$ENDIF}

procedure TDownloadFile.OnRequestCompleted(const Sender: TObject; const AResponse: IHTTPResponse);
var
  FileName: String;
  DestinationFile: String;
begin

  if Assigned(FFileStream) then
    FFileStream.Free;

  if FDownloadStatus = TDownloadStatus.dsAborted then
    Exit;

  if AResponse.StatusCode = FILE_NOT_FOUND then
  begin
    FDownloadStatus := TDownloadStatus.dsNotFound;
    FHasContent := False;
    Exit;
  end;

{$IFDEF USING_ATTACHMENT}
  FFileName := ExtractAttachmentFileName(AResponse.GetHeaders);
  // Opcionalmente o usuario poderia ser questionado para informar um nome de arquivo,
  // porém este erro não deveria acontecer
  Assert(not FFileName.IsEmpty, 'Nome de arquivo não foi recuperado');
{$ENDIF}
  if FHasContent then
  begin
    FileName := FDownloadDirectory + TPath.DirectorySeparatorChar + FFileName;
    DeleteFile(FFileName);
    FDownloadStatus := TDownloadStatus.dsDone;
    if RenameFile(FTemporaryFileName, FileName) then
    begin
      FDownloadStatus := TDownloadStatus.dsDone;
      DeleteFile(FTemporaryFileName);
    end;
  end;

  FHasContent := False;
end;

procedure TDownloadFile.setFilesToDownload(const Value: TStringDynArray);
begin
  FFilesToDownload := Value;
end;

procedure TDownloadFile.OnReceiveData(const Sender: TObject; AContentLength, AReadCount: Int64; var Abort: Boolean);
begin
  if not Self.IsDownloading then
  begin
    Abort := true;
    Exit;
  end;
  if AContentLength > 0 then
    FHasContent := true;

  FPosition := Round(100 * (AReadCount / AContentLength));

end;

function TDownloadFile.HasFileToDownload: TDownloadErrorLevel;
var
  FileName: String;
begin
  FTotalFilesInQueue := 0;
  Result := TDownloadErrorLevel.dlNoFiles;
  for FileName in FFilesToDownload do
    if FileName.Trim <> '' then
    begin
      Result := TDownloadErrorLevel.dlHasFile;
      Inc(FTotalFilesInQueue);
    end;

  // Caso alguma url se torne invalida, todo o processo será
  // abortado, porque a sanitização das url apenas consegue
  // dar alguma garantia quanto ao formato, mas não ao existência
  // do recurso.
  if Result = TDownloadErrorLevel.dlHasFile then
    if not SanitizeUrl(FFilesToDownload) then
      Result := TDownloadErrorLevel.dlInvalidUrl;
end;

procedure TDownloadFile.InitializeDownloader;
begin
  LinkDownloader := TThread.CreateAnonymousThread(
    procedure
    var
      Url: String;
    begin
      FFileInQueue := 1;

      try
        for Url in FFilesToDownload do
        begin

          if Url.IsEmpty then
            Continue;

          FTemporaryFileName := TPath.GetTempFileName;
          FFileName := ExtractFileNameFromUrl(Url);
          try
            FFileStream := TFileStream.Create(FTemporaryFileName, fmCreate);
          except
            FDownloadStatus := TDownloadStatus.dsError;
            Continue;
          end;

          try
            FDownloadStatus := TDownloadStatus.dsDownloading;
            // Estamos considerando que o arquivo é distribuido via recurso de link
            // e não via alguma API, e neste ultimo caso o programa deveria utilizar
            // o define USING_ATTACHMENT. Além disso, no mundo real o downloader
            // poderia dar ao usuario a oportunidade de continuar ou abortar toda a fila
            // caso algum arquivo apresente erro, no momento ele segue para o próximo
            FHttpEngine.Get(Url, FFileStream);
          Except
            FDownloadStatus := TDownloadStatus.dsError;
          end;

          if TThread.Current.CheckTerminated then
            Break;

          Inc(FFileInQueue);
        end;

      finally

        if FDownloadStatus = TDownloadStatus.dsDownloading then
          FDownloadStatus := TDownloadStatus.dsFinished;

        FIsDownloading := False;
        FFileName := '';
      end;

    end);
  LinkDownloader.start;
end;

procedure TDownloadFile.DownloadFiles;
begin
  InitializeDownloader();
end;

procedure TDownloadFile.StartDownload;
var
  TestFiles: TDownloadErrorLevel;
begin
  FIsDownloading := true;
  TestFiles := HasFileToDownload();

  if TestFiles = TDownloadErrorLevel.dlNoFiles then
    raise Exception.Create('Não há arquivo para baixar');

  if TestFiles = TDownloadErrorLevel.dlInvalidUrl then
    raise Exception.Create('Url para download é invalida');

  DownloadFiles();
end;

end.
