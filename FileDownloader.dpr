program FileDownloader;

uses
  Vcl.Forms,
  FileController.Main.View in 'View\FileController.Main.View.pas' {ViewDownload},
  FileDownload.Downloader.Controller in 'Control\FileDownload.Downloader.Controller.pas' {$R *.res},
  Vcl.Themes,
  Vcl.Styles,
  FileDownload.Common.Controller in 'Control\FileDownload.Common.Controller.pas',
  FileDownloader.DataModule in 'Model\FileDownloader.DataModule.pas' {FileDownloaderDataModule: TDataModule};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Windows10');
  Application.CreateForm(TViewDownload, ViewDownload);
  Application.CreateForm(TFileDownloaderDataModule, FileDownloaderDataModule);
  Application.Run;

end.
