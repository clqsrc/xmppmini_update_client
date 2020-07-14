unit http_client;

{$mode objfpc}{$H+}

//主要是 lazarus 中代替 TIdHTTP 的控件

interface

uses
  Classes,

  {$IFDEF FPC}
  fphttp, fphttpclient,
  {$ELSE}
  XMLIntf,
  XMLDoc,
  IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdHTTP,
  {$ENDIF}

  SysUtils;

function HttpGet(url:string; ATimeout:Integer = 10000):String;
//la 的返回值只认 200 返回码，所以要自定义一个
//参考 procedure TFPCustomHTTPClient.Get(const AURL: String; Stream: TStream);
procedure HttpGet(http:TFPHTTPClient; const AURL: String; Stream: TStream); overload;

implementation

function HttpGet(url:string; ATimeout:Integer = 10000):String;
var
  http:TFPHTTPClient;
begin
  Result := '';


  try
    try
      http := TFPHTTPClient.Create(nil);
      //http.IOTimeout := 3000;  //不知道单位是不是毫秒
      http.IOTimeout := ATimeout;  //不知道单位是不是毫秒

      if Trim(url) = '' then Exit;

      Result := http.Get(url);
    finally
      http.Free;
    end;

  except
  end;

end;

//la 的返回值只认 200 返回码，所以要自定义一个
//参考 procedure TFPCustomHTTPClient.Get(const AURL: String; Stream: TStream);
procedure HttpGet(http:TFPHTTPClient; const AURL: String; Stream: TStream); overload;
begin
  http.HTTPMethod('GET',AURL,Stream,[200, 206]);
end;

end.

