{
  *********************************
  (C)riado por Magno Lima 2022
  *********************************
}
unit FileDownload.Common.Controller;

interface

uses
  System.Classes, Winapi.Windows, System.IOUtils, ShlObj, System.Types,
  System.SysUtils, System.RegularExpressions;

const
  TEST_URL_REGEX = '^(https?:\/\/)?([\da-z\.-]+\.[a-z\.]{2,6}|[\d\.]+)([\/:?=&#]{1}[\da-z\.-]+)*[\/\?]?$';

function GetSpecialFolderPath(CSIDLFolder: Integer): string;
function TryGetDownloadFolder: String;
function ExtractFileNameFromUrl(const AUrl: string): string;
function SanitizeUrl(Const ListOfUrl: TStringDynArray): Boolean;

implementation

function GetSpecialFolderPath(CSIDLFolder: Integer): string;
var
  FilePath: array [0 .. MAX_PATH] of char;
begin
  SHGetFolderPath(0, CSIDLFolder, 0, 0, FilePath);
  Result := FilePath;
end;

function ExtractFileNameFromUrl(const AUrl: string): string;
var
  Index: Integer;
begin
  Index := LastDelimiter('/', AUrl);
  Result := Copy(AUrl, Index + 1, Length(AUrl) - Index);
end;

function TryGetDownloadFolder: String;
var
  DownloadFolder: String;
begin
{$IF Defined(MSWINDOWS)}
  DownloadFolder := GetSpecialFolderPath(CSIDL_PROFILE) + '\Downloads';
{$ELSE}
  DownloadFolder := TPath.GetSharedDocumentsPath;
{$ENDIF}
  Result := DownloadFolder;
end;

function SanitizeUrl(Const ListOfUrl: TStringDynArray): Boolean;
var
  Url: String;
  RegularExpression: TRegEx;
begin
  for Url in ListOfUrl do
    if not Url.IsEmpty then
    begin
      RegularExpression := TRegEx.Create(TEST_URL_REGEX, [roIgnoreCase, roMultiline]);
      Result := RegularExpression.Match(Url).Success;
      if not Result then
        Break;
    end;
end;

end.
