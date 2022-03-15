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
    FDownloader: TThread;
    FStartTime: TDateTime;
    FEndTime: TDateTime;
    FUrl: String;
    FListOfErrors: TStringList;
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
    function CreateStreamFile(const AURL: String): Boolean;
    function BeginDownload(const AURL: String): Boolean;
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
    property Url: String read FUrl;
    property DownloadFolder: String read FDownloadDirectory write FDownloadDirectory;
    property FileName: String read FFileName;
    property TotalFilesInQueue: Integer read FTotalFilesInQueue;
    property FileInQueue: Integer read FFileInQueue;
    property Status: TDownloadStatus read FDownloadStatus;
    property ErrorLevel: TDownloadErrorLevel read FErrorLevel;
    property StartTime: TDateTime read FStartTime;
    property EndTime: TDateTime read FEndTime;
    property ListOfErrors: TStringList read FListOfErrors;
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
  FListOfErrors := TStringList.Create;
end;

destructor TDownloadFile.Destroy;
begin
  Self.ClearList;
  FListOfErrors.Free;
  FreeAndNil(FHttpEngine);
  inherited;
end;

procedure TDownloadFile.ClientRequestError(const Sender: TObject; const AError: string);
begin
  FDownloadStatus := TDownloadStatus.dsError;
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

// Estamos considerando que o arquivo é distribuido via recurso de link,
// para eventuais casos de API o programa deveria utilizar o define USING_ATTACHMENT
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
    ListOfErrors.Add(FFileName+' não encontrado');
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
    FEndTime := Now();
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

procedure TDownloadFile.Abort;
begin
  FIsDownloading := False;
  FDownloadStatus := TDownloadStatus.dsAborted;

  if Assigned(FDownloader) and FDownloader.Started then
    FDownloader.Terminate;

  Self.ClearList;

end;

procedure TDownloadFile.OnReceiveData(const Sender: TObject; AContentLength, AReadCount: Int64; var Abort: Boolean);
begin

  if FDownloadStatus = TDownloadStatus.dsAborted then
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

  // Caso alguma url se torne inválida, todo o processo será
  // abortado, porque a sanitização das url apenas consegue
  // dar alguma garantia quanto ao formato, mas não ao existência
  // do recurso.
  if Result = TDownloadErrorLevel.dlHasFile then
    if not SanitizeUrl(FFilesToDownload) then
      Result := TDownloadErrorLevel.dlInvalidUrl;
end;

function TDownloadFile.CreateStreamFile(const AURL: String): Boolean;
begin
  FTemporaryFileName := TPath.GetTempFileName;
  FFileName := ExtractFileNameFromUrl(AURL);
  try
    FFileStream := TFileStream.Create(FTemporaryFileName, fmCreate);
    Result := true;
  except
    Result := False;
  end;
end;

function TDownloadFile.BeginDownload(const AURL: String): Boolean;
begin
  FUrl := AURL;
  FDownloadStatus := TDownloadStatus.dsDownloading;
  FStartTime := Now();
  FEndTime := FStartTime;
  Result := CreateStreamFile(Url);

  if Result then
  begin

    FHttpEngine.Get(AURL, FFileStream);

    if FDownloadStatus = TDownloadStatus.dsNotFound then
      Sleep(1);

  end;
  FEndTime := Now();

end;

procedure TDownloadFile.InitializeDownloader;
begin
  FIsDownloading := true;
  FDownloader := TThread.CreateAnonymousThread(
    procedure
    var
      Url: String;
    begin
      FFileInQueue := 1;

      try
        for Url in FFilesToDownload do
        begin

          try
            if not BeginDownload(Url) then
              Continue;


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
  FDownloader.FreeOnTerminate := true;
  FDownloader.start;
end;

procedure TDownloadFile.DownloadFiles;
begin
  InitializeDownloader();
end;

procedure TDownloadFile.StartDownload;
var
  TestFiles: TDownloadErrorLevel;
begin

  TestFiles := HasFileToDownload();

  if TestFiles = TDownloadErrorLevel.dlNoFiles then
    raise Exception.Create('Não há arquivo para baixar');

  if TestFiles = TDownloadErrorLevel.dlInvalidUrl then
    raise Exception.Create('Url para download é invalida');

  DownloadFiles();

end;

end.
