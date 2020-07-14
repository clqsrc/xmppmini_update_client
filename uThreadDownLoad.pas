unit uThreadDownLoad;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,


  {$IFDEF FPC}
  fphttp, fphttpclient,
  {$ELSE}
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,
  IdHTTP,
  {$ENDIF}


  Dialogs;

{$IFDEF FPC}
type
  TWorkMode = Integer;

{$ELSE}

{$ENDIF}

type
  TThreadDownLoad = class;
  TThreadDownLoadEvent2 = procedure(thread:TThreadDownLoad; tag:Integer; const out1:string; succeed:boolean);  //没有控件的

type
  TThreadDownLoad = class(TThread)
  private
    //下载到的文件位置
    curPos:Integer;
    //全部的大小
    totalSize:Integer;
    //当前的范围
    curRange1,curRange2:Integer;
    curSize:Integer;
    curFile:TFileStream;
    //下载的出错次数
    netErrCount:Integer;



    function GetTotalSize(s: string): Integer;
    function GetTotalSize_Http:Boolean;
    procedure GetRange(s: string);
    procedure IdHTTP_OnWork(Sender: TObject; AWorkMode: TWorkMode;
      const AWorkCount: Integer);


    {$IFDEF FPC}
    function DownBlock_la: Boolean;
    {$ELSE}
    function DownBlock_d7: Boolean;
    {$ENDIF}
    function DownBlock: Boolean;

    procedure DoDownComplete;

  protected
    procedure Execute; override;
  public
    //下载什么文件
    fileName:string;
    //每次下载多大
    blockSize:Integer;

    {$IFDEF FPC}
    http:TFPHTTPClient;
    {$ELSE}
    http:TIdHTTP;
    {$ENDIF}


    Response:string;
    httpFileName:string;

    //test
    AWorkCount:Integer;

    txtInfo:String;

    //DoDownComplete 中调用，线程安全
    OnDownComplete:TThreadDownLoadEvent2;

    tag:Integer; //目前用于 OnDownComplete
    localFileName:string; //2020 下载后的本地地的文件名


    //在主界面上显示信息
    procedure ShowInfo;
    //在主界面上显示信息
    procedure ShowInfo2;

    procedure _ShowInfo_String;
    procedure ShowInfo_String(Const _s:String);
    function GetLocalFileName:String;
  end;

var
  DebugHook:Integer = 0;

implementation

uses
  http_client,
  la_functions,
  uUpdateMain;

{ Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);

  and UpdateCaption could look like,

    procedure TThreadDownLoad.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end; }

{ TThreadDownLoad }


function TThreadDownLoad.GetLocalFileName:String;
var
  _localFileName:String;
  fn:String;
begin
  //2020 不用默认文件名，用 http 地址计算出来
  //httpFileName := GHttpFileName;
  _localFileName := ExtractFileName(httpFileName);
  fn := ExtractFilePath(Application.ExeName) + 'update_down\' + _localFileName;
  ForceDirectories(ExtractFilePath(Application.ExeName) + 'update_down');

  _localFileName := fn; //存一下完整路径，后面还有用

  Result := _localFileName;
end;

procedure TThreadDownLoad.Execute;
var
  fn:string;
begin

  try
    //--------------------------------------------------
    //初始化
    curPos := 0;

    {$IFDEF FPC}
    http := TFPHTTPClient.Create(nil);
    //http.OnDataReceived := ;   //2020 la 下是什么事件?
    {$ELSE}
    http := TIdHTTP.Create(nil);
    http.OnWork := Self.IdHTTP_OnWork;
    {$ENDIF}


    //--------------------------------------------------

  //  http.Request.CustomHeaders.Values['Range'] := 'bytes=1024-2048';//对应的回应可能是 "Content-Range"
  //  //Response := http.Get('http://www.csdn.net');
  //  http.Get('http://127.0.0.1:8080/20130502.1.rar?a=1&b=2&c=123');

    //--------------------------------------------------
    //curFile := TFileStream.Create('c:\2.rar', fmCreate or fmShareDenyNone);
    ////fn := ExtractFilePath(Application.ExeName) + 'update.zip';

    //2020 不用默认文件名，用 http 地址计算出来
    //httpFileName := GHttpFileName;
    fn := GetLocalFileName();

    localFileName := fn; //存一下完整路径，后面还有用

    if FileExists(fn) then
    begin
      //已有文件的从断点打开
      curFile := TFileStream.Create(fn, fmOpenWrite or fmShareDenyNone);
      curPos := curFile.Size;
      curFile.Seek(0, soEnd);
    end
    else
      curFile := TFileStream.Create(fn, fmCreate or fmShareDenyNone);

    //循环下载,直到结束,每次 blockSize 大小
    netErrCount := 0;//下载的出错次数
    while True do
    begin
      if DownBlock()= False then Break;
      if netErrCount>10 then Break;//错了 10 次就退出吧

      //Synchronize(ShowInfo);
      Synchronize(@ShowInfo); //la 下要加地址符
    end;
    curFile.Free;

  except
  end;

  Synchronize(@DoDownComplete);
  //ShowInfo;

end;

{$IFDEF FPC}

{$ELSE}
function TThreadDownLoad.DownBlock_d7:Boolean;
var
  mem:TMemoryStream;
  curLen:Integer;
begin
  Result := True;

  if GStop = True then
  begin
    Result := False;
    Exit;
  end;

  mem := TMemoryStream.Create;
  try//奇怪,我的 indy 现在不抛出异常了,但又能 try 到
    //--------------------------------------------------
    curLen := curPos + blockSize;//重新计算当前要下载的长度更好,不过目前这样可以测试服务器的容错

    //http.Request.CustomHeaders.Values['Range'] := 'bytes=1024-2048';//对应的回应可能是 "Content-Range"
    http.Request.CustomHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(curPos + blockSize);//对应的回应可能是 "Content-Range"

    //http.ConnectTimeout := 10000;
    //http.ReadTimeout := 10000;//不够
    http.ReadTimeout := 30000;

    //Response := http.Get('http://www.csdn.net');
    //http.Get('http://127.0.0.1:8080/20130502.1.rar?a=1&b=2&c=123', mem);
    //http.Get('http://127.0.0.1:8080/20130514.zip?a=1&b=2&c=123', mem);
    //http.Get('http://192.168.1.183:8090/' + httpFileName + '?a=1&b=2&c=123', mem);
    //http.Get('http://fyguilin.fuyoo.net:8090/' + httpFileName + '?a=1&b=2&c=123', mem);
    if GHttpFileName = '' then
    http.Get('http://' + GIP + ':' + IntToStr(GPort) + '/' + httpFileName + '?a=1&b=2&c=123', mem)
    else
    http.Get(GHttpFileName, mem);




    //mem.SaveToFile('c:\1.rar');
    mem.Position := 0;

    curFile.CopyFrom(mem, mem.Size);

    GetTotalSize(http.Response.RawHeaders.Values['Content-Range']);

    //--------------------------------------------------
    //循环下载,直到结束,每次 blockSize 大小

    //回应代码必须检验的// 2015/7/9 11:55:36//正常的一般是 206
    if DebugHook<>0 then
    if http.ResponseCode>=400
    then MessageBox(0, PChar('Content-Range:' + http.Response.ResponseText), '文件下载错误', MB_OK or MB_ICONWARNING);

    //range 返回值计算出的当前下载大小,如果出错了,与 mem.Size 是不同的
    if DebugHook<>0 then
    if curSize=0
    then MessageBox(0, PChar('Content-Range:' + http.Response.ResponseText), '文件下载错误', MB_OK or MB_ICONWARNING);

    if mem.Size < 1
    then Result := False;

    //当前位置已经移动到超过了就结束了,因为 curPos 是从0开始的,所以两者相等时就结束了
    if curPos>=totalSize
    then Result := False;


    netErrCount := 0;//本次下载成功的话重置错误计数
  except
    //MessageBox(0, '网络访问失败.', '', MB_OK or MB_ICONWARNING);

    //win2003 的原生 iis 有一个奇特的 bug 当请求的 rang 超过范围时会始终返回一个字节,但第二次连接时则会生成 'bytes */5021483' 的 range 头
    //这时的回应码为 'HTTP/1.1 416 Requested Range Not Satisfiable'

    //回应代码必须检验的// 2015/7/9 11:55:36//正常的一般是 206
    if http.ResponseCode>=400 then
    begin
      Result := False;
      mem.Free;
      Exit;
    end;

    if DebugHook<>0 then MessageBox(0, PChar('Content-Range:' + http.Response.RawHeaders.Values['Content-Range']), '文件下载错误', MB_OK or MB_ICONWARNING);
    //下载的出错次数
    Inc(netErrCount);
  end;

  mem.Free;
end;


{$ENDIF}

function TThreadDownLoad.DownBlock:Boolean;
begin
  {$IFDEF FPC}
  Result := DownBlock_la();
  {$ELSE}
  Result := DownBlock_d7();
  {$ENDIF}
end;

//----
//阿里云的 oss 有一个 bug , 当传输的 ['Range'] 大于文件大小时，它会返回整个文件！ 并且不再含有 ['Range'] 回应，估计它这时认为请求中也没有 ['Range']
//这显然很可怕，如果是几个 G 的那还得了，所以应当多一个过程，先取 0-1 个字节，先得到 totalSize 再进行后面的操作
//所以要有一个独立的取 totalSize resourcestring 过程
//只取一次就行了
//和 DownBlock_la 也差不多，只是只取一个字节，并且取回的内容不存回文件中
function TThreadDownLoad.GetTotalSize_Http:Boolean;
var
  mem:TMemoryStream;
  _downSize:Integer;

  //以下是为方便和全局变量同名
  _curPos:Integer;

begin

  Result := True;

  if GStop = True then
  begin
    Result := False;
    Exit;
  end;

  mem := TMemoryStream.Create;
  try//奇怪,我的 indy 现在不抛出异常了,但又能 try 到
    //--------------------------------------------------

    //http.Request.CustomHeaders.Values['Range'] := 'bytes=1024-2048';//对应的回应可能是 "Content-Range"
    //http.Request.CustomHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(curPos + blockSize);//对应的回应可能是 "Content-Range"
    //http.RequestHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(curPos + blockSize);//对应的回应可能是 "Content-Range"
    //不对，如果是 0-1 ，那么取得的是两个字节的内容，所以应该取 0-0 后面的下载终点范围也是一样的
    http.RequestHeaders.Values['Range'] := 'bytes='+ IntToStr(0) + '-' + IntToStr(0);//对应的回应可能是 "Content-Range" //只取一个字节


    //http.ConnectTimeout := 10000;
    //http.ReadTimeout := 10000;//不够
//    http.ReadTimeout := 30000;
    http.IOTimeout := 30000;  //2020 不知道单位是否也是毫秒

    //la 的返回值只认 200 返回码，所以要自定义一个
    HttpGet(http, Self.httpFileName, mem);

    //----
    //阿里云的 oss 有一个 bug , 当传输的 ['Range'] 大于文件大小时，它会返回整个文件！ 并且不再含有 ['Range'] 回应，估计它这时认为请求中也没有 ['Range']
    //这显然很可怕，如果是几个 G 的那还得了，所以应当多一个过程，先取 0-1 个字节，先得到 totalSize 再进行后面的操作

    _downSize := mem.Size;
    ShowInfo_String('当前取得数据长度为：'+ IntToStr(_downSize) + ' ' + IntToStr(_downSize div 1024) + 'K ' + IntToStr(_downSize div (1024*1024)) + 'm');

    //---------------------------------------------------
    //mem.SaveToFile('c:\1.rar');
    ////mem.SaveToFile('d:\2.rar');
    mem.Position := 0;

    //不行，要先判断是否有 'Content-Range'
    ////curFile.CopyFrom(mem, mem.Size);  //将下载内容加入到文件中

    //----------------------------------------------------

    _curPos := curPos; //curPos 会被修改，所以先保存一下原来的值

    //GetTotalSize(http.Response.RawHeaders.Values['Content-Range']);
    //ShowMessage(http.ResponseHeaders.Text); //2020 注意，la 通过 ResponseHeaders.Values 取标识时前面会多一个空格
    GetTotalSize(http.ResponseHeaders.Values['Content-Range']);  //2020 注意，la 通过 ResponseHeaders.Values 取标识时前面会多一个空格

    curPos := _curPos;  //一定要恢复原值
    //--------------------------------------------------
    //循环下载,直到结束,每次 blockSize 大小

    //回应代码必须检验的// 2015/7/9 11:55:36//正常的一般是 206
    if DebugHook<>0 then
    //if http.ResponseCode>=400
    //then MessageBox(0, PChar('Content-Range:' + http.Response.ResponseText), '文件下载错误', MB_OK or MB_ICONWARNING);
    if http.ResponseStatusCode>=400
    then MessageBox(0, PChar('Content-Range:' + http.ResponseStatusText), '文件下载错误', MB_OK or MB_ICONWARNING);

    //range 返回值计算出的当前下载大小,如果出错了,与 mem.Size 是不同的
    if DebugHook<>0 then
    if curSize=0
    then MessageBox(0, PChar('Content-Range:' + http.ResponseStatusText), '文件下载错误', MB_OK or MB_ICONWARNING);

    if mem.Size < 1
    then Result := False;

    //当前位置已经移动到超过了就结束了,因为 curPos 是从0开始的,所以两者相等时就结束了
    if curPos>=totalSize
    then Result := False;


    netErrCount := 0;//本次下载成功的话重置错误计数
  except
    //MessageBox(0, '网络访问失败.', '', MB_OK or MB_ICONWARNING);

    //win2003 的原生 iis 有一个奇特的 bug 当请求的 rang 超过范围时会始终返回一个字节,但第二次连接时则会生成 'bytes */5021483' 的 range 头
    //这时的回应码为 'HTTP/1.1 416 Requested Range Not Satisfiable'

    //回应代码必须检验的// 2015/7/9 11:55:36//正常的一般是 206
    if http.ResponseStatusCode>=400 then
    begin
      Result := False;
      mem.Free;
      Exit;
    end;

    if DebugHook<>0 then MessageBox(0, PChar('Content-Range:' + http.ResponseHeaders.Values['Content-Range']), '文件下载错误', MB_OK or MB_ICONWARNING);
    //下载的出错次数
    Inc(netErrCount);
  end;

  mem.Free;

end;


//返回 false 时这个文件的整个下载过程结束
function TThreadDownLoad.DownBlock_la:Boolean;
var
  mem:TMemoryStream;
  curLen:Integer;
  _downSize:Integer;
  _endPos:Integer; //2020 还要精确的计算最后的位置
begin
  Result := True;

  if GStop = True then
  begin
    Result := False;
    Exit;
  end;

  //--------------------------------------------------------
  //为避免阿里云对错误 Range 头会返回全部内容的问题，这里先取一个文件的整个大小
  if totalSize = 0 then
  begin
    GetTotalSize_Http();
    ShowInfo_String('文件大小为：' + IntToStr(totalSize));
  end;

  if curPos >= totalSize then //如果当前位置大于全部或者等于，就认为下载完成了
  begin
    ShowInfo_String('已下载完全部内容。');
    Result := False;
    Exit;
  end;
  //--------------------------------------------------------

  mem := TMemoryStream.Create;
  try//奇怪,我的 indy 现在不抛出异常了,但又能 try 到
    //--------------------------------------------------
    curLen := curPos + blockSize;//重新计算当前要下载的长度更好,不过目前这样可以测试服务器的容错
    _endPos := curPos + blockSize;
    //2020 最后的位置并不是 totalSize 而是 totalSize-1 所以只取一个字节的话 range 就是 0-0 而不是 0-1
    //if _endPos > totalSize then _endPos := totalSize; //2020 一定要精确计算，否则阿里云这样的服务器可能会认为是错误的 range 头而返回整个文件！
    if _endPos > (totalSize-1) then _endPos := totalSize - 1; //2020 一定要精确计算，否则阿里云这样的服务器可能会认为是错误的 range 头而返回整个文件！

    //http.Request.CustomHeaders.Values['Range'] := 'bytes=1024-2048';//对应的回应可能是 "Content-Range"
    //http.Request.CustomHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(curPos + blockSize);//对应的回应可能是 "Content-Range"
    //http.RequestHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(curPos + blockSize);//对应的回应可能是 "Content-Range"
    http.RequestHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(_endPos);//对应的回应可能是 "Content-Range"

    ShowInfo_String('当前下载位置：' + IntToStr(curPos) + ' ' + IntToStr(curPos div 1024) + 'K ' + IntToStr(curPos div (1024*1024)) + 'm');

    //http.ConnectTimeout := 10000;
    //http.ReadTimeout := 10000;//不够
//    http.ReadTimeout := 30000;
    http.IOTimeout := 30000;  //2020 不知道单位是否也是毫秒

    //Response := http.Get('http://www.csdn.net');
    //http.Get('http://127.0.0.1:8080/20130502.1.rar?a=1&b=2&c=123', mem);
    //http.Get('http://127.0.0.1:8080/20130514.zip?a=1&b=2&c=123', mem);
    //http.Get('http://192.168.1.183:8090/' + httpFileName + '?a=1&b=2&c=123', mem);

    //la 的返回值只认 200 返回码，所以要自定义一个
    HttpGet(http, Self.httpFileName, mem);

    //----
    //阿里云的 oss 有一个 bug , 当传输的 ['Range'] 大于文件大小时，它会返回整个文件！ 并且不再含有 ['Range'] 回应，估计它这时认为请求中也没有 ['Range']
    //这显然很可怕，如果是几个 G 的那还得了，所以应当多一个过程，先取 0-1 个字节，先得到 totalSize 再进行后面的操作

    _downSize := mem.Size;
    ShowInfo_String('当前取得数据长度为：'+ IntToStr(_downSize) + ' ' + IntToStr(_downSize div 1024) + 'K ' + IntToStr(_downSize div (1024*1024)) + 'm');

    //---------------------------------------------------
    //mem.SaveToFile('c:\1.rar');
    ////mem.SaveToFile('d:\1.rar');
    mem.Position := 0;

    //不行，要先判断是否有 'Content-Range'
    curFile.CopyFrom(mem, mem.Size);  //将下载内容加入到文件中

    //----------------------------------------------------

//    GetTotalSize(http.Response.RawHeaders.Values['Content-Range']);
    //ShowMessage(http.ResponseHeaders.Text); //2020 注意，la 通过 ResponseHeaders.Values 取标识时前面会多一个空格
    GetTotalSize(http.ResponseHeaders.Values['Content-Range']);  //2020 注意，la 通过 ResponseHeaders.Values 取标识时前面会多一个空格

    //--------------------------------------------------
    //循环下载,直到结束,每次 blockSize 大小

    //回应代码必须检验的// 2015/7/9 11:55:36//正常的一般是 206
    if DebugHook<>0 then
    //if http.ResponseCode>=400
    //then MessageBox(0, PChar('Content-Range:' + http.Response.ResponseText), '文件下载错误', MB_OK or MB_ICONWARNING);
    if http.ResponseStatusCode>=400
    then MessageBox(0, PChar('Content-Range:' + http.ResponseStatusText), '文件下载错误', MB_OK or MB_ICONWARNING);

    //range 返回值计算出的当前下载大小,如果出错了,与 mem.Size 是不同的
    if DebugHook<>0 then
    if curSize=0
    then MessageBox(0, PChar('Content-Range:' + http.ResponseStatusText), '文件下载错误', MB_OK or MB_ICONWARNING);

    if mem.Size < 1
    then Result := False;

    //当前位置已经移动到超过了就结束了,因为 curPos 是从0开始的,所以两者相等时就结束了
    if curPos>=totalSize
    then Result := False;


    netErrCount := 0;//本次下载成功的话重置错误计数
  except
    //MessageBox(0, '网络访问失败.', '', MB_OK or MB_ICONWARNING);

    //win2003 的原生 iis 有一个奇特的 bug 当请求的 rang 超过范围时会始终返回一个字节,但第二次连接时则会生成 'bytes */5021483' 的 range 头
    //这时的回应码为 'HTTP/1.1 416 Requested Range Not Satisfiable'

    //回应代码必须检验的// 2015/7/9 11:55:36//正常的一般是 206
    if http.ResponseStatusCode>=400 then
    begin
      Result := False;
      mem.Free;
      Exit;
    end;

    if DebugHook<>0 then MessageBox(0, PChar('Content-Range:' + http.ResponseHeaders.Values['Content-Range']), '文件下载错误', MB_OK or MB_ICONWARNING);
    //下载的出错次数
    Inc(netErrCount);
  end;

  mem.Free;
end;


//解码当前的下载范围
procedure TThreadDownLoad.GetRange(s:string);
var
  i:Integer;
  bf:Boolean;//找到起始字符了
  s1:string;
  s2:string;
begin

  bf := False;
  s1 := '';
  s2 := '';

  for i := 1 to Length(s) do
  begin
    if bf = False then
    begin
      //得到当前的范围
      if s[i]='-' then
      begin
        bf := True;
        Continue;
      end;

      s1 := s1 + s[i];
    end
    else
    begin
      s2 := s2 + s[i];

    end;
  end;

  curRange1 := StrToIntDef(s1, -1);//0);
  curRange2 := StrToIntDef(s2, -1);//0);// 2015/7/9 14:14:50 不对, http 下载协议中 0 是有意义的,如果两者都是 0 表示的下载第 1 个字节!所以初始应当为 -1


  //if (curRange2>curRange1)and(curRange1>=0) then
  if (curRange2>=curRange1)and(curRange1>=0) then //两者是可以相等的// 2015/7/9 15:15:06
  begin
    //curPos := curRange2; //两者位置相等的话表示取当前位置的1个字节,所以这个数量是要加 1 的
    curPos := curRange2 + 1;
    //curSize := curRange2 - curRange1;
    curSize := curRange2 - curRange1 + 1; //两者位置相等的话表示取当前位置的1个字节,所以这个数量是要加 1 的
  end;  

end;

//解码出总大小等于
function TThreadDownLoad.GetTotalSize(s:string):Integer;
var
  i:Integer;
  bf:Boolean;//找到起始字符了
  bt:Boolean;//找到总大小字符了
  st:string;
  range:string;
begin
  Result := 0;

  s := Trim(s); //la 得到的前面会多一个空格，所以要先去掉//2020 注意，la 通过 ResponseHeaders.Values 取标识时前面会多一个空格

  bf := False;
  bt := False;
  st := '';
  range := '';

  for i := 1 to Length(s) do
  begin
    if bf = False then
    begin
      //bf := True;
      //得到当前的范围
      if s[i]=' ' then
      begin
        bf := True;
        Continue;
      end;
    end
    else
    begin
      if (bt = False)and(s[i]<>'/') then range := range + s[i];

    end;

    if bt = False then
    begin
      //得到当前的范围
      if s[i]='/' then
      begin
        bt := True;
        Continue;
      end;
    end
    else
    begin
      st := st + s[i];

    end;

  end;

  GetRange(range);
  totalSize := StrToIntDef(st, 0);
  Result := StrToIntDef(st, 0);

end;

procedure TThreadDownLoad.ShowInfo;
begin
//  ShowMessage(Response);
//  //ShowMessage(http.Response.ResponseText);
//  ShowMessage(http.Response.RawHeaders.Text);//扩展的头信息可以在这里得到
//  ShowMessage(http.Response.RawHeaders.Values['Content-Range']);
//
//  ShowMessage(IntToStr(GetTotalSize(http.Response.RawHeaders.Values['Content-Range'])));

  if totalSize > 0 then
  begin
    frmUpdateMain.ProgressBar_DownLoad.Position := Trunc(curPos * 100 / totalSize);
    frmUpdateMain.Image2.Width := Trunc(frmUpdateMain.Image1.Width * (curPos / totalSize));
  end;
  
end;

//下载完成了
procedure TThreadDownLoad.DoDownComplete;
var
  succeed:Boolean;
begin
  //ShowMessage(Response);
  ////ShowMessage(http.Response.ResponseText);
  //ShowMessage(http.Response.RawHeaders.Text);//扩展的头信息可以在这里得到
  //ShowMessage(http.Response.RawHeaders.Values['Content-Range']);

  //ShowMessage(IntToStr(GetTotalSize(http.Response.RawHeaders.Values['Content-Range'])));

  if nil<>OnDownComplete then
  begin
    succeed := True;;
    OnDownComplete(self, Self.tag, Self.httpFileName, succeed);
  end;

  if netErrCount>10 then
  begin
    ShowMessage('网络异常,请您择时重新下载.');
    ////Application.Terminate;
    Exit;
  end;

  if totalSize > 0 then
  frmUpdateMain.ProgressBar_DownLoad.Position := Trunc(curPos * 100 / totalSize);

  //frmUpdateMain.Image2.Width := frmUpdateMain.Image1.Width * Trunc(curPos / totalSize);

  //if curPos = totalSize then
  if curPos >= totalSize then//因为有可能是另外一个程序,所以有可能大于
  begin
    {
    frmUpdateMain.btnUpdate.Enabled := True;
    
    //ShowMessage('下载完成,将进行程序更新,请确保原程序已经退出.');
    if GForceUpdate = True then//强制更新的时候都不用问
    begin
      ShowMessage('下载完成,将进行程序更新,请确保原程序已经退出.');
    end
    else  
    if MessageBox_New(Application.Handle, '已经为您准备好程序的最新版本,是否现在进行更新?', '提示') <> True then
    begin
      ////Application.Terminate;
      Exit;
    end;

    //下载完成后自动进行更新
    frmUpdateMain.btnUpdateClick(frmUpdateMain.btnUpdate);
    }
  end;

end;

procedure TThreadDownLoad.IdHTTP_OnWork(Sender: TObject; AWorkMode: TWorkMode;
  const AWorkCount: Integer);
begin
  //
//  curPos := AWorkCount;
//
//  Synchronize(ShowInfo);

  Self.AWorkCount := AWorkCount;
  Synchronize(@ShowInfo2);

end;

procedure TThreadDownLoad.ShowInfo2;
begin
  //frmUpdateMain.Caption := IntToStr(AWorkCount);
  
end;

procedure TThreadDownLoad._ShowInfo_String;
begin
  frmUpdateMain.txtInfo.Caption := Self.txtInfo;

end;


procedure TThreadDownLoad.ShowInfo_String(Const _s:String);
var
  s:String;
begin

  s := AnsiToUtf8_delphi7(_s);

  Self.txtInfo := s;

  Synchronize(@_ShowInfo_String);

end;

end.
