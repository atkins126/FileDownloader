object FileDownloaderDataModule: TFileDownloaderDataModule
  OldCreateOrder = False
  OnCreate = DataModuleCreate
  OnDestroy = DataModuleDestroy
  Height = 150
  Width = 215
  object SQLConnection: TFDConnection
    Params.Strings = (
      
        'Database=C:\DEVELOPER\FONTES\Teste Softplan\Resources\FileDownlo' +
        'ader.db'
      'DriverID=SQLite')
    BeforeConnect = SQLConnectionBeforeConnect
    Left = 32
    Top = 16
  end
end
