{
  *********************************
  (C)riado por Magno Lima 2022
  *********************************
  Não formatar!!
}
const
  RESOURCE_DIR = '.\Database\';
  DATABASE_NAME = 'FileDownloader.db';
  DDL_DATABASE =
    'CREATE TABLE LOGDOWNLOAD ( ' +
    '    CODIGO     INTEGER       PRIMARY KEY AUTOINCREMENT,'+
    '    URL        VARCHAR (600) NOT NULL,	' +
    '    DATAINICIO DATE          NOT NULL,	' +
    '    DATAFIM    DATE)';
 SQL_INSERT_URL =
    'INSERT INTO LOGDOWNLOAD(URL,        '+
    '                        DATAINICIO, '+
    '                        DATAFIM)    '+
    '                 VALUES(:URL,       '+
    '                        :DATAINICIO,'+
    '                        :DATAFIM);  ';

