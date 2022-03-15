{
  *********************************
  (C)riado por Magno Lima 2022
  *********************************

  Existem algumas particularidades quando
  tratamos com o SQLite em termos de criacao
  do banco e inserção de dados, como a necessidade
  de fechar o banco para salvar o "journal"
}
unit FileDownloader.DataModule;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.VCLUI.Wait, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, System.Generics.Collections, System.TypInfo;

{$INCLUDE Database_Information.inc}

type
  TDataUrl = class
  private
    FCodigo: Integer;
    FURL: String;
    FDataInicio: TDateTime;
    FDataFim: TDateTime;
  published
    property Codigo: Integer read FCodigo write FCodigo;
    property URL: String read FURL write FURL;
    property DataInicio: TDateTime read FDataInicio write FDataInicio;
    property DataFim: TDateTime read FDataFim write FDataFim;
  end;

type
  TFileDownloaderDataModule = class(TDataModule)
    SQLConnection: TFDConnection;
    procedure SQLConnectionBeforeConnect(Sender: TObject);
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    procedure CreateDatabase;

    { Private declarations }
  public
    { Public declarations }
    ListOfLogDownload: TList<TDataUrl>;
    procedure EmptyLog;
    procedure InsertLog(DataUrl: TDataUrl);
    procedure OpenLog;

  end;

var
  FileDownloaderDataModule: TFileDownloaderDataModule;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

procedure TFileDownloaderDataModule.OpenLog;
var
  query: TFDQuery;
  LogDownload: TDataUrl;
  i: Integer;
begin
  query := TFDQuery.create(nil);

  Self.EmptyLog();

  try
    query.Connection := SQLConnection;
    query.Sql.Text := 'SELECT * FROM LOGDOWNLOAD';
    query.Open;
    while not query.Eof do
    begin
      LogDownload := TDataUrl.create;
      for i := 0 to query.Fields.Count - 1 do
        SetPropValue(LogDownload, query.Fields[i].FieldName, query.Fields[i].Value);
      ListOfLogDownload.Add(LogDownload);
      query.Next;
    end;
  finally
    FreeAndNil(query);
  end;
end;

procedure TFileDownloaderDataModule.EmptyLog;
var
  LogDownload: TDataUrl;
begin
  for LogDownload in ListOfLogDownload do
    FreeAndNil(LogDownload);
  ListOfLogDownload.Clear;
  ListOfLogDownload.TrimExcess;
end;

procedure TFileDownloaderDataModule.CreateDatabase();
var
  query: TFDQuery;
begin
  query := TFDQuery.create(nil);
  try
    query.Connection := SQLConnection;
    query.Sql.Text := DDL_DATABASE;
    query.ExecSQL;
  finally
    FreeAndNil(query);
  end;
  SQLConnection.Close;
end;

procedure TFileDownloaderDataModule.DataModuleCreate(Sender: TObject);
begin
  ForceDirectories(RESOURCE_DIR);
  if not FileExists(RESOURCE_DIR + DATABASE_NAME) then
    CreateDatabase();

  ListOfLogDownload := TList<TDataUrl>.create;

end;

procedure TFileDownloaderDataModule.DataModuleDestroy(Sender: TObject);
begin
  Self.EmptyLog;
  FreeAndNil(ListOfLogDownload);
end;

procedure TFileDownloaderDataModule.SQLConnectionBeforeConnect(Sender: TObject);
begin
  SQLConnection.Params.Values['Database'] := RESOURCE_DIR + DATABASE_NAME;
end;

procedure TFileDownloaderDataModule.InsertLog(DataUrl: TDataUrl);
var
  query: TFDQuery;
begin
  query := TFDQuery.create(nil);
  try
    query.Connection := SQLConnection;
    query.Sql.Text := SQL_INSERT_URL;
    query.ParamByName('URL').AsString := DataUrl.URL;
    query.ParamByName('DATAINICIO').AsDateTime := DataUrl.DataInicio;
    query.ParamByName('DATAFIM').AsDateTime := DataUrl.DataFim;
    query.ExecSQL;
  finally
    FreeAndNil(query);
  end;
  SQLConnection.Close;
end;

end.
