{
  *********************************
  (C)riado por Magno Lima 2022

  A database SQLite será criada na primeira execução
  na pasta \Database no mesmo nível do executável.
  A lista de arquivos é gerada dinamicamente e são
  simples endereços url saltados por linha.
  O processo não é multithread e as variáveis usadas
  na engine de download não são thread-safe!

  Mais informações no README.md
  https://github.com/magnolima/FileDownloader
  *********************************
}
unit FileController.Main.View;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, System.Generics.Collections, System.Threading,
  Vcl.ComCtrls, System.IOUtils,
  Vcl.CheckLst, Vcl.WinXPanels, Vcl.ExtCtrls, Vcl.Buttons,
  System.Actions, Vcl.ActnList,
  FileDownload.Common.Controller,
  FileDownload.Downloader.Controller,
  FileDownloader.DataModule, Vcl.Grids;

const
  RESOURCE_LINK = '.\resources_link.txt';

type
  TMLStringGrid = class(TStringGrid)
  public
    procedure AddRow(ARow: TDataUrl);
  end;

type
  TViewDownload = class(TForm)
    btReturn: TButton;
    btAction: TButton;
    CardPanel: TCardPanel;
    cardFileSelection: TCard;
    cardDownload: TCard;
    ProgressBar1: TProgressBar;
    lbInfo: TLabel;
    lbFile: TLabel;
    mmInfo: TMemo;
    cbFilesToDownload: TCheckListBox;
    Label1: TLabel;
    sbAddLink: TSpeedButton;
    sbDeleteLink: TSpeedButton;
    edLink: TEdit;
    Label2: TLabel;
    sbClearAll: TSpeedButton;
    edDownloadFolder: TEdit;
    lbDestination: TLabel;
    sbSelectFolder: TSpeedButton;
    sbClearedLink: TSpeedButton;
    btShowLog: TButton;
    cardDownloadHistory: TCard;
    sgLogDownload: TStringGrid;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btNextClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure cbFilesToDownloadClickCheck(Sender: TObject);
    procedure cbFilesToDownloadClick(Sender: TObject);
    procedure sbAddLinkClick(Sender: TObject);
    procedure sbClearAllClick(Sender: TObject);
    procedure sbDeleteLinkClick(Sender: TObject);
    procedure sbSelectFolderClick(Sender: TObject);
    procedure sbClearedLinkClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btReturnClick(Sender: TObject);
    procedure btActionClick(Sender: TObject);
    procedure btShowLogClick(Sender: TObject);
    procedure ResetLogDownloadGrid;
  private
    procedure ForkGUI;
    function AddLink(const NewLink: String; ListOfLinks: TCheckListBox): Boolean;
    procedure DeleteLink(ListOfLinks: TCheckListBox);
    procedure DownloadFinished;
    procedure ShowDownloadHistory;
    procedure LoadDownloadGrid;
    procedure UpdateGUI(const Detail: String);
    procedure InsertLogDownload;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ViewDownload: TViewDownload;
  DownloadFile: TDownloadFile;
  DownloadFolder: String;

implementation

{$R *.dfm}

procedure TViewDownload.UpdateGUI(const Detail: String);
begin
  lbFile.Caption := Detail;
  ProgressBar1.Position := DownloadFile.Position;
  if DownloadFile.Status = dsNotFound then
    mmInfo.Lines.Add(Detail + ': não encontrado.');
  if DownloadFile.Status = dsDone then
  begin
    InsertLogDownload();
    mmInfo.Lines.Add(Detail + ': baixado com sucesso.');
  end;
end;

procedure TViewDownload.InsertLogDownload;
var
  DataUrl: TDataUrl;
begin
  DataUrl := TDataUrl.Create;
  DataUrl.URL := DownloadFile.Url;
  DataUrl.DataInicio := DownloadFile.StartTime;
  DataUrl.DataFim := DownloadFile.EndTime;
  FileDownloaderDataModule.InsertLogDownload(DataUrl);
end;

procedure TViewDownload.ForkGUI;
begin
  tthread.CreateAnonymousThread(
    procedure
    var
      InQueue: Integer;
      Detail: String;
    begin

      InQueue := 0;

      while DownloadFile.IsDownloading do
      begin

        if DownloadFile.Status = dsNone then
          Continue;

        if DownloadFile.FileInQueue <> InQueue then
        begin
          Detail := Format('%s - %d/%d', [DownloadFile.FileName, DownloadFile.FileInQueue, DownloadFile.TotalFilesInQueue]);
          InQueue := DownloadFile.FileInQueue;
          ProgressBar1.Max := 100;
          ProgressBar1.Position := 0;
        end;

        tthread.Synchronize(tthread.CurrentThread,
          procedure
          begin
            UpdateGUI(Detail);
          end);
      end;

      tthread.Synchronize(nil,
        procedure
        begin
          DownloadFinished();
        end);

    end).Start;
end;

procedure TViewDownload.DownloadFinished;
begin
  if DownloadFile.Status = dsAborted then
    MessageDlg('Download interrompido', TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], 0);

  if DownloadFile.Status = dsError then
    MessageDlg('Erro ao receber arquivo', TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);

  btAction.Caption := 'Download';
  btReturn.Enabled := True;
end;

function TViewDownload.AddLink(const NewLink: String; ListOfLinks: TCheckListBox): Boolean;
begin
  if NewLink.IsEmpty then
    exit;
  Result := SanitizeUrl([NewLink.Trim]);
  if Result and (ListOfLinks.Items.IndexOf(NewLink.Trim) = -1) then
  begin
    ListOfLinks.Items.Add(NewLink.Trim);
    ListOfLinks.Items.SaveToFile(RESOURCE_LINK);
  end;

end;

procedure TViewDownload.sbAddLinkClick(Sender: TObject);
begin
  if AddLink(edLink.Text, cbFilesToDownload) then
    edLink.Clear
  else if edLink.Text <> '' then
    MessageDlg('Link informado parece estar mal formado', TMsgDlgType.mtWarning, [TMsgDlgBtn.mbOK], 0)
end;

procedure TViewDownload.sbClearAllClick(Sender: TObject);
begin
  cbFilesToDownload.Clear;
  DeleteFile(RESOURCE_LINK);
end;

procedure TViewDownload.DeleteLink(ListOfLinks: TCheckListBox);
begin
  if ListOfLinks.ItemIndex = -1 then
    exit;
  ListOfLinks.DeleteSelected;
  ListOfLinks.Items.SaveToFile(RESOURCE_LINK);
end;

procedure TViewDownload.sbDeleteLinkClick(Sender: TObject);
begin
  DeleteLink(cbFilesToDownload);
end;

procedure TViewDownload.sbSelectFolderClick(Sender: TObject);
var
  OpenDialog: TFileOpenDialog;
begin
  OpenDialog := TFileOpenDialog.Create(ViewDownload);
  try
    OpenDialog.DefaultFolder := DownloadFolder;
    OpenDialog.Options := OpenDialog.Options + [fdoPickFolders];
    if not OpenDialog.Execute then
      Abort;
    DownloadFolder := OpenDialog.FileName;
  finally
    OpenDialog.Free;
  end;
end;

procedure TViewDownload.sbClearedLinkClick(Sender: TObject);
begin
  edLink.Clear;
end;

procedure TViewDownload.cbFilesToDownloadClick(Sender: TObject);
begin
  if cbFilesToDownload.ItemIndex <> -1 then
    edLink.Text := cbFilesToDownload.Items[cbFilesToDownload.ItemIndex];
end;

procedure TViewDownload.cbFilesToDownloadClickCheck(Sender: TObject);
var
  i: Integer;
begin
  btAction.Enabled := False;
  for i := 0 to Pred(cbFilesToDownload.Count) do
    if cbFilesToDownload.checked[i] then
    begin
      btAction.Enabled := True;
      break;
    end;
end;

procedure TViewDownload.btActionClick(Sender: TObject);
begin

  if DownloadFile.IsDownloading then
  begin
    if MessageDlg('Interromper download?', TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
      DownloadFile.Abort;
    exit;
  end;

  CardPanel.ActiveCard := cardDownload;
  btReturn.Visible := True;
  btAction.Caption := 'Cancelar';
  DownloadFile.DownloadFolder := DownloadFolder;
  DownloadFile.FilesToDownload := ['https://magnumlabs.com.br/eyeson/eyesonapk', 'https://magnumlabs.com.br/eyeson/eyeson.apk'];
  DownloadFile.StartDownload;
  ForkGUI();
end;

procedure TViewDownload.btNextClick(Sender: TObject);
begin

  if DownloadFile.Status = TDownloadStatus.dsFinished then
    Close;

  if DownloadFile.IsDownloading then
  begin
    if MessageDlg('Interromper download?', TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
      DownloadFile.Abort;
  end;

  if DownloadFile.Status = dsAborted then
    MessageDlg('Download interrompito', TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], 0);

  if DownloadFile.Status = dsError then
    MessageDlg('Erro ao receber arquivo', TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);

end;

procedure TViewDownload.btReturnClick(Sender: TObject);
begin
  CardPanel.ActiveCard := cardFileSelection;
  btReturn.Visible := False;
  btReturn.Enabled := False;
end;

procedure TViewDownload.LoadDownloadGrid;
var
  LogDownload: TDataUrl;
begin
  FileDownloaderDataModule.OpenLog();
  for LogDownload in FileDownloaderDataModule.ListOfLogDownload do
    TMLStringGrid(sgLogDownload).AddRow(LogDownload);

end;

procedure TViewDownload.ShowDownloadHistory;
begin
  ResetLogDownloadGrid();
  LoadDownloadGrid();
end;

procedure TViewDownload.btShowLogClick(Sender: TObject);
begin
  if CardPanel.ActiveCard = cardDownloadHistory then
  begin
    btShowLog.Caption := 'Exibir histórico de downloads';
    CardPanel.ActiveCard := cardFileSelection;
    exit;
  end;
  btShowLog.Caption := 'Retornar';
  CardPanel.ActiveCard := cardDownloadHistory;
  ShowDownloadHistory();
end;

procedure TViewDownload.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if DownloadFile.IsDownloading then
    DownloadFile.Abort;
  DownloadFile.Free;
end;

procedure TViewDownload.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not DownloadFile.IsDownloading;
  if DownloadFile.IsDownloading then
    ShowMessage('Download em andamento. Interrompa primeiro.')
end;

procedure TViewDownload.ResetLogDownloadGrid;
begin
  sgLogDownload.RowCount := 0;
  sgLogDownload.RowCount := 2;
  sgLogDownload.FixedRows := 1;
  sgLogDownload.Cells[0, 0] := 'Código';
  sgLogDownload.Cells[1, 0] := 'Inicio';
  sgLogDownload.Cells[2, 0] := 'Fim';
  sgLogDownload.Cells[3, 0] := 'URL';
end;

procedure TViewDownload.FormCreate(Sender: TObject);
begin
  DownloadFile := TDownloadFile.Create(Self);
  CardPanel.ActiveCard := cardFileSelection;
  ResetLogDownloadGrid();
end;

procedure TViewDownload.FormShow(Sender: TObject);
begin
  // Para fins de exemplo vamos carregar recursos de um arquivo
  if FileExists(RESOURCE_LINK) then
    cbFilesToDownload.Items.LoadFromFile(RESOURCE_LINK);

  // Para windows este metodo poderá falhar caso o usuario tenha movido
  // sua pasta de download do local default. No mundo real iremos testar
  // a validade e permitir que o diretorio escolhido seja salvo
  DownloadFolder := TryGetDownloadFolder();
  edDownloadFolder.Text := DownloadFolder;

  FileDownloaderDataModule.SQLConnection.Open;

end;

{ TMyStringGrid }

procedure TMLStringGrid.AddRow(ARow: TDataUrl);
begin
  Self.Cells[0, Self.RowCount - 1] := ARow.Codigo.ToString;
  Self.Cells[1, Self.RowCount - 1] := DateTimeToStr(ARow.DataInicio);
  Self.Cells[2, Self.RowCount - 1] := DateTimeToStr(ARow.DataFim);
  Self.Cells[3, Self.RowCount - 1] := ARow.URL;
  Self.RowCount := Self.RowCount + 1;

end;

initialization

// Tratar leak de memoria quando fechar a tela durante download
ReportMemoryLeaksOnShutdown := True;

end.
