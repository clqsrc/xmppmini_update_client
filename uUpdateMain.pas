unit uUpdateMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls,
  //VCLZip, VCLUnZip, uFormVSkin,

  {$IFDEF FPC}

  {$ELSE}
  XMLIntf,
  XMLDoc,
  IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdHTTP,
  {$ENDIF}

  ExtCtrls;

type
  //TfrmUpdateMain = class(TFormVSkin)
  TfrmUpdateMain = class(TForm)
    btnUpdate1:TPanel;
    btnUpdate2:TPanel;
    ImagePanel1:TPanel;
    OpenDialog1:TOpenDialog;
    txtInfo:TLabel;
    pnlCaptionRight:TPanel;
    pnlClient:TPanel;
    ProgressBar_DownLoad: TProgressBar;
    btnDownLoad: TPanel;
    Panel1: TPanel;
    btnUpdate: TPanel;
    Image1: TPanel;
    Image2: TPanel;
    procedure btnDownLoadClick(Sender: TObject);
    procedure btnUpdate1Click(Sender:TObject);
    procedure btnUpdate2Click(Sender:TObject);
    procedure btnUpdateClick(Sender: TObject);

    procedure FormCreate(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
  private

    procedure LoadConfig;
    { Private declarations }
  public
    { Public declarations }
    slLatest:TStringList;
    latestFileName:string;
    httpFileName:string;
  end;

//统一界面风格的询问对话框//注:不能在线程中使用,如果要在线程中还是得使用原始的 MessagBox
function MessageBox_New(hWnd: HWND; sText, sCaption: string): Boolean;


var
  frmUpdateMain: TfrmUpdateMain;
  GStop:Boolean = False;

  GMainExe:string = '';//主程序
  Glatest:string = ''; //要从 http 下载的信息
  //GHttpFileName:string = ''; //要从 http 下载的信息
  _GHttpFileName:string = '';

  // 2013-10-29 9:06:11 不问了,使用当前流行的静默下载方式,招商的也是这样的
  GAutoDownFile:Boolean = False;//True;
  GForceUpdate:Boolean = False;//是否强制更新


  //--------------------------------------------------
  //隐藏传递的公司名
  GCompanyName : string = 'xm';

implementation

uses
  uThreadDownLoad, md5,
  //zipper, //lazarus 自带
  //sggzip,
  la_zip,
  LConvEncoding,
  LazUTF8,
  la_functions,
  md5_check,
  http_client;
  //uKillAppExe;

{$R *.dfm}

//统一界面风格的询问对话框//注:不能在线程中使用,如果要在线程中还是得使用原始的 MessagBox
function MessageBox_New(hWnd: HWND; sText, sCaption: string): Boolean;
var
  r:Integer;
begin
  r := MessageBox(hWnd, PAnsiChar(sText),  PAnsiChar(sCaption), MB_YESNO );

  if r = IDYES then Result := True
  else Result := False;
end;  


function Zip(ZipMode,PackSize:Integer;ZipFile,UnzipDir:String):Boolean; //压缩或解压缩文件
//var
//  ziper:TVCLZip;
begin
  {
  //函数用法：Zip(压缩模式，压缩包大小，压缩文件，解压目录)
  //ZipMode为0：压缩；为1：解压缩　PackSize为0则不分包；否则为分包的大小
  try
    if copy(UnzipDir, length(UnzipDir), 1) = '\' then
    UnzipDir := copy(UnzipDir, 1, length(UnzipDir) - 1); //去除目录后的“\”
    
    ziper:=TVCLZip.Create(application);//创建zipper
    ziper.DoAll:=true;//加此设置将对分包文件解压缩有效
    ziper.OverwriteMode:=Always;//总是覆盖模式

    if PackSize<>0 then begin//如果为0则压缩成一个文件，否则压成多文件
      ziper.MultiZipInfo.MultiMode:=mmBlocks;//设置分包模式
      ziper.MultiZipInfo.SaveZipInfoOnFirstDisk:=True;//打包信息保存在第一文件中
      ziper.MultiZipInfo.FirstBlockSize:=PackSize;//分包首文件大小
      ziper.MultiZipInfo.BlockSize:=PackSize;//其他分包文件大小
    end;

    ziper.FilesList.Clear;
    ziper.ZipName := ZipFile; //获取压缩文件名
    
    if ZipMode=0 then begin //压缩文件处理
      ziper.FilesList.Add(UnzipDir+'\*.*');//添加解压缩文件列表
      Application.ProcessMessages;//响应WINDOWS事件
      ziper.Zip;//压缩
    end else begin
      ziper.DestDir:= UnzipDir;//解压缩的目标目录
      ziper.RecreateDirs := True;//要加这个才能在解压时带目录
      ziper.UnZip; //解压缩
    end;

    ziper.Free; //释放压缩工具资源
    Result:=True; //执行成功
  except
    Result:=False;//执行失败
  end;
  }
end;

procedure TfrmUpdateMain.btnDownLoadClick(Sender: TObject);
var
  thread:TThreadDownLoad;
begin
  GStop := False;
  btnDownLoad.Enabled := False;

  //----
  GetHttpFileInfo_index := 0; //当前文件信息是第几个文件的，从 0 开始
  GetHttpFile_index := 0; //当前下载的第几个文件，从 0 开始

  //----
  //取第一级文件
  GetHttpFileName_List;

  exit;
  //----

  //每次下 40 K
  thread := TThreadDownLoad.Create(True);
  thread.blockSize := 40 * 1024;
  thread.httpFileName := Self.httpFileName;


  thread.Resume;

  
end;


procedure TfrmUpdateMain.btnUpdateClick(Sender: TObject);
var
  h:THandle;
  md5:string;
  fn:string;
begin

  if nil = GHttpFileName_List then
  begin
    ShowMessage(AnsiToUtf8_delphi7('请先下载文件。'));
    Exit;
  end;
  MakeLocalFileMd5_All();
  //CopyFileAll();

  Exit;//2020
  //--------------------------------------------------
  //先杀死试试
  //KillAppExe(GMainExe); //2020 la 下有些 windows api 函数用不了
  Sleep(3000);


  //--------------------------------------------------

  //只允许启动一个实例
  h := CreateMutex(nil, false, 'MarketV3');
  if (GetLastError() = ERROR_ALREADY_EXISTS) then
  begin
    //CloseHandle(hMutex);
    MessageBox(Application.Handle, '程序正在运行中，请退出后再进行更新！', '提示', MB_OK or MB_ICONWARNING);
    //oldWindow := FindWindow('TfrmLogin', nil);

    //奇怪,存在的情况下也是要释放的,否则会重复报警的
    ReleaseMutex(h);
    CloseHandle(h);

    Self.Show;//静默下载时主窗口未必是打开的,所以要显示一下

    Exit;
  end;

  ReleaseMutex(h);
  CloseHandle(h);

  btnDownLoad.Enabled := False;
  btnUpdate.Enabled := False;

  //--------------------------------------------------
  //Zip(1, 0, 'c:\1.zip', 'c:\2');
  fn := ExtractFilePath(Application.ExeName) + 'update.zip';
  md5 := MD5DigestToString(MD5File(fn));

  if md5<>slLatest.Values['MD5'] then
  begin
    ShowMessage('文件损坏,请重新下载.');
    DeleteFile(fn);
    btnDownLoad.Enabled := True;
    Exit;
  end;  

  Zip(1, 0, fn, ExtractFileDir(Application.ExeName));
  ShowMessage('更新完成.');
  slLatest.SaveToFile(latestFileName);
  //删除文件
  CopyFile(PChar(ExtractFilePath(Application.ExeName) + 'update.zip'), PChar(ExtractFilePath(Application.ExeName) + 'update.old.zip'), False);
  DeleteFile(ExtractFilePath(Application.ExeName) + 'update.zip');

  //启动主程序
  WinExec(PChar(ExtractFilePath(Application.ExeName) + GMainExe), SW_SHOWNORMAL);

  ExitProcess(0);

end;


procedure TfrmUpdateMain.LoadConfig;
var
  i : Integer;
  sl:TStringList;

begin
  sl := TStringList.Create;
  sl.LoadFromFile(ExtractFilePath(Application.ExeName) + 'config_updateclient.txt');

  //ShowMessage(response);

  try

    //--------------------------------------------------
    //升级服务器地址

    GCompanyName := sl.Values['CompanyName'];

    GMainExe := sl.Values['MainExe'];

    // 2015/7/9 10:41:04 要下载的文件的信息
		//latest="http://127.0.0.1/latest.txt"
		//HttpFileName="http://127.0.0.1/update.zip"
    Glatest := sl.Values['latest'];
    _GHttpFileName := sl.Values['HttpFileName'];
    GHttpFileName_List_Fn := sl.Values['HttpFileName'];

    

    //--------------------------------------------------

  //finally
  except
    //GLoadConfigError := True;
    ShowMessage(sl.Text);//不是 xml 格式

  end;
//  XML.Free;

  sl.Free;


end;


procedure TfrmUpdateMain.FormCreate(Sender: TObject);
begin
  //Application.Title := '更新程序';

  slLatest := TStringList.Create;
  latestFileName := ExtractFilePath(Application.ExeName) + 'latest.txt';

  LoadConfig();

  Image2.Width := 0;

  //--------------
  //2020
  if GAutoDownFile then btnDownLoadClick(btnDownLoad);

end;

procedure TfrmUpdateMain.btnStopClick(Sender: TObject);
begin
  GStop := True;
  Sleep(1000);
  btnDownLoad.Enabled := True;

  GetHttpFileInfo_index := 0; //当前文件信息是第几个文件的，从 0 开始
  GetHttpFile_index := 0; //当前下载的第几个文件，从 0 开始
end;

procedure TfrmUpdateMain.btnUpdate1Click(Sender:TObject);
var
  fn,path:String;
  r:Boolean;
begin
  path := ExtractFilePath(Application.ExeName) + 'update';

  fn := ExtractFilePath(Application.ExeName) + 'update.zip';

  ForceDirectories(path);

  //la 的解压模块不能解压超过原文件大小的文件，所以兼容性没 winrar 好。不过可以覆盖原有文件，并且正确解压的目录
  r := UnZip(fn, path);

  //if False = r Then ShowMessage(AnsiToUtf8('zip 文件损坏'));
  //if False = r Then ShowMessage(CP936ToUTF8('zip 文件损坏')); //LConvEncoding , lazarus 下 AnsiToUtf8 是不能转换 gbk 的源码的
  //(CP936ToUTF8

  //LazUTF8.UTF8ToWinCP(s);
  //if False = r Then ShowMessage(LazUTF8.WinCPToUTF8('zip 文件损坏')); //这个也可以

  if False = r Then ShowMessage(AnsiToUtf8_delphi7('zip 文件损坏')) //这个也可以
  else ShowMessage(AnsiToUtf8_delphi7('解压完毕。'));

end;

procedure TfrmUpdateMain.btnUpdate2Click(Sender:TObject);
var
  s:String;
begin

  if OpenDialog1.Execute = False Then Exit;

  MakeLocalFileMd5(OpenDialog1.FileName);
  //GetFileMd5(OpenDialog1.FileName);

  ShowMessage('ok');

  Exit;
  //----
  s := GetFileMd5(ExtractFilePath(Application.ExeName) + 'update.zip');

  s := ExtractFileName('http://softhub.newbt.net/174/174--1.html');
  ShowMessage(s);

  GetHttpFileName_List();

end;


end.
