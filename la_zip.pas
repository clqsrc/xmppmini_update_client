unit la_zip;

//lazarus 的 zip 解码

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

function UnZip(ZipFile,UnzipDir:String):Boolean; //压缩或解压缩文件

implementation

uses
  zipper;

//function UnZip(ZipMode,PackSize:Integer;ZipFile,UnzipDir:String):Boolean; //压缩或解压缩文件
function UnZip(ZipFile,UnzipDir:String):Boolean; //压缩或解压缩文件
var
  UnZipper: TUnZipper;
begin

  Result := False;

  try

    //http://wiki.freepascal.org/paszlib
    UnZipper := TUnZipper.Create;

    try
      UnZipper.FileName := ZipFile;//'E:\20120411\zip\zip.zip';
      UnZipper.OutputPath := UnzipDir;//'E:\20120411\zip\a';

      UnZipper.UnZipAllFiles; //unzip
    finally
      UnZipper.Free;
    end;

    Result := True;

  except
  end;

end;

end.

