unit md5_check;

{$mode objfpc}{$H+}

//文件的检测和下载

//目前由以下几个层级文件组成
//1.全部或者是有可能需要更新的全部文件的列表
//2.每个文件的属性文件。其中需要记录文件的 md5 标识,如果是压缩文件，还要标识压缩是否，以及压缩后的 md5 值

interface

uses
  Classes, SysUtils, md5, Dialogs,
  uThreadDownLoad,
  fileutil, //copyfile
  Forms;

var
  GHttpFileName_List:TStringList = nil; //要下载的全部文件名，全路径
  GHttpFileName_List_Fn:String; //包含 GHttpFileName_List 内容的文件名

  GetHttpFileInfo_index:Integer; //当前文件信息是第几个文件的，从 0 开始
  GetHttpFile_index:Integer; //当前下载的第几个文件，从 0 开始

//取得一个文件的 md5 字符串//注意大小写，这个应该是小写字符串的
function GetFileMd5(fn:String):String;

//取第一级文件，文件列表
function GetHttpFileName_List:Boolean;

//取第二级文件，文件属性
function GetHttpFileInfo(fn:string):Boolean;

//取第三级文件，文件实际内容
function GetHttpFile(fn:string; OnDownComplete:TThreadDownLoadEvent2):Boolean;

//计算本地文件的 md5 值
procedure MakeLocalFileMd5(fn:String);

//计算本地文件的 md5 值
procedure MakeLocalFileMd5_All();

//版本信息文件直接复制不进行校验
//procedure CopyFile_Ver();

implementation

uses
  la_zip,
  uUpdateMain;

//文件中是否有错误
var
  gFileMd5Error:Boolean;

const
  GHttpFileName_Ver:String='file_ver.txt';

procedure _ShowMessage(const aMsg: string);
begin
  //ShowMessage(sl.Text);
end;

//取得一个文件的 md5 字符串
function GetFileMd5(fn:String):String;
var
  d:MD5Digest;
begin
  d := MD5File(fn);

  Result := MD5Print(d);
end;


procedure On_GetHttpFileName_List(thread:TThreadDownLoad; tag:Integer; const out1:string; succeed:boolean);
var
  sl:TStringList;
  fn:String;
begin
  sl := TStringList.Create;

  try
    sl.LoadFromFile(thread.localFileName);
    _ShowMessage(sl.Text);

    GHttpFileName_List.Text := sl.Text;

    //--------
    //下载文件属性
    GetHttpFileInfo_index := 0; //从 0 开始，不需要记录中间位置，因为已下载的不会再下载。校验错误时会删除再下载。

    fn := GHttpFileName_List.Strings[GetHttpFileInfo_index];
    if Trim(fn)>'' then fn := GHttpFileName_List.Strings[GetHttpFileInfo_index] + '.info.txt';

    GetHttpFileInfo(fn);

  finally
    sl.Free;
  end;
  //线程安全
  //ShowMessage('On_GetHttpFileName_List');

end;

//取第一级文件
function GetHttpFileName_List:Boolean;
var
  thread:TThreadDownLoad;
begin
  Result := False;

  GStop := False;

  //----
  //应该重置一下各个变量
  GetHttpFileInfo_index := 0; //当前文件信息是第几个文件的，从 0 开始
  GetHttpFile_index := 0; //当前下载的第几个文件，从 0 开始
  //----

  if GHttpFileName_List = nil Then GHttpFileName_List := TStringList.Create;
  GHttpFileName_List.Clear;

  //每次下 40 K
  thread := TThreadDownLoad.Create(True);
  thread.blockSize := 40 * 1024;

  //这个文件无法校验，因此每次都取最新的。所以要先删除
  //DeleteFile(GHttpFileName_List_Fn);

  thread.httpFileName := GHttpFileName_List_Fn; //Self.httpFileName;

  DeleteFile(thread.GetLocalFileName); //这个文件无法校验，因此每次都取最新的。所以要先删除

  thread.OnDownComplete := @On_GetHttpFileName_List;

  thread.Resume;

end;


function On_GetHttpFile_check_ver:boolean;
var
  fn:String;
  ver,old_ver:String;
  sl:TStringList;
begin
  Result := False;

  ver := '';
  old_ver := '';

  sl := TStringList.Create;;
  try

    //----------------
    //如果版本一致了，为节省下载流量和对用户的干扰可以不再向下，这要求文件列表中第一个就是版本文件

    sl.Clear;
    fn := ExtractFilePath(Application.ExeName) + GHttpFileName_Ver;
    if FileExists(fn) then
    begin
      sl.LoadFromFile(fn);
      old_ver := sl.Values['ver'];

    end;


    sl.Clear;
    fn := ExtractFilePath(Application.ExeName) + 'update_down\' + GHttpFileName_Ver;
    if FileExists(fn) then
    begin
      sl.LoadFromFile(fn);
      ver := sl.Values['ver'];

    end;

    if (Length(Trim(ver))>1)and(old_ver = ver)
    then Result := True;


  finally
    sl.Free;
  end;
end;

procedure On_GetHttpFile(thread:TThreadDownLoad; tag:Integer; const out1:string; succeed:boolean);
var
  fn:String;

begin

  try

    //----------------
    //如果版本一致了，为节省下载流量和对用户的干扰可以不再向下，这要求文件列表中第一个就是版本文件
    fn := GHttpFileName_List.Strings[GetHttpFile_index];
    if GHttpFileName_Ver = LowerCase(Trim(ExtractFileName(fn))) then   //如果是版本信息文件
    begin
      if True = On_GetHttpFile_check_ver then
      begin

        if GAutoDownFile then
        begin
          //ShowMessage('版本一致，准备退出更新程序。');

          Application.Terminate;

        end
        else
        begin
          ShowMessage('版本一致，无需更新。');
        end;

        Exit;
      end;
    end;

    //----------------
    //先校验下载到的文件，如果 md5 不正确应该重新下载，不过这样会死循环，如果文件不对的话，所以还是提示后再说

    //----------------
    //如果有下一个文件，再取
    GetHttpFile_index := GetHttpFile_index + 1;

    if GetHttpFile_index < GHttpFileName_List.Count  then
    begin
      fn := GHttpFileName_List.Strings[GetHttpFile_index];
      GetHttpFile(fn, @On_GetHttpFile);  //取下一个文件
    end
    else   //所有文件全部完成了
    begin
      ShowMessage('自动更新：所有文件全部下载完成了!');

      //计算本地文件的 md5 值
      MakeLocalFileMd5_All();

      //上面的过程会复制文件，但不包括版本信息
      //CopyFile_Ver();  //还是要放到 MakeLocalFileMd5_All 中，因为有 GAutoDownFile 时退出整个程序过程
    end;

  finally

  end;
  //线程安全
  //ShowMessage('On_GetHttpFile');

end;

procedure On_GetHttpFileInfo_check_file(fn:String);
var
  fn_file, fn_last_update:String;
  sl1,sl2:TStringList;
  r:Boolean;
begin
  //
  if Trim(fn) = '' then Exit;

  fn := ExtractFileName(fn);

  fn_file := ExtractFilePath(Application.ExeName) + 'update_down\' + fn;
  fn := fn_file + '.info.txt';
  fn_last_update := fn_file + '.info.txt.last_update.txt';

  //if False = FileExists(fn_last_update) then Exit; //没有更新过就不管了

  sl1 := TStringList.Create;
  sl2 := TStringList.Create;

  if FileExists(fn)
  then sl1.LoadFromFile(fn);

  if FileExists(fn_last_update)
  then sl2.LoadFromFile(fn_last_update);

  if sl1.Text<>sl2.Text then //信息文件不同，说明版本不对，那就要删除已经下载的部分
  begin
    r := DeleteFile(fn_file);

    //文件可能不存在，所以
    if False = FileExists(fn_file) then r := True;

    if True = r  //旧的下载文件删除成功后应当立即更新信息文件，因为后面下载的都是最新的了，不更新的话下次下载时又会被删除
    then CopyFile(fn, fn_last_update);



  end;

  sl1.Free;
  sl2.Free;
end;

procedure On_GetHttpFileInfo(thread:TThreadDownLoad; tag:Integer; const out1:string; succeed:boolean);
var
  sl:TStringList;
  fn:String;
begin
  sl := TStringList.Create;

  try
    if FileExists(thread.localFileName)
    then sl.LoadFromFile(thread.localFileName);

    _ShowMessage(sl.Text);

    //----------------
    //应该先校验文件信息，如果发生变化应该先删除旧文件，否则全部下载完成时再校验会导致本次更新失败
    //如果有上次的更新文件并且 md5 值不同的话，删除旧文件
    On_GetHttpFileInfo_check_file(GHttpFileName_List.Strings[GetHttpFileInfo_index]);

    //----------------
    //如果有下一个文件，再取
    GetHttpFileInfo_index := GetHttpFileInfo_index + 1;

    if GetHttpFileInfo_index < GHttpFileName_List.Count  then
    begin
      fn := GHttpFileName_List.Strings[GetHttpFileInfo_index];
      if Trim(fn)> '' then fn := GHttpFileName_List.Strings[GetHttpFileInfo_index] + '.info.txt'; //空文件名不加，以便后继处理
      GetHttpFileInfo(fn);

    end
    else   //如果文件信息都下载完了，则下载文件本身
    begin
      GetHttpFile_index := 0;
      fn := GHttpFileName_List.Strings[GetHttpFile_index];
      GetHttpFile(fn, @On_GetHttpFile);
    end;

  finally
    sl.Free;
  end;
  //线程安全
  //ShowMessage('On_GetHttpFileInfo');

end;


//取第二级文件，文件属性
function GetHttpFileInfo(fn:string):Boolean;
var
  thread:TThreadDownLoad;
begin
  Result := False;

  GStop := False;

  //if GHttpFileName_List = nil Then GHttpFileName_List := TStringList.Create;
  //GHttpFileName_List.Clear;

  //每次下 40 K
  thread := TThreadDownLoad.Create(True);
  thread.blockSize := 40 * 1024;
  thread.httpFileName := fn; //GHttpFileName_List_Fn; //Self.httpFileName;

  DeleteFile(thread.GetLocalFileName); //这个文件无法校验，因此每次都取最新的。所以要先删除

  thread.OnDownComplete := @On_GetHttpFileInfo;

  thread.Resume;

end;



//取第三级文件，文件实际内容
function GetHttpFile(fn:string; OnDownComplete:TThreadDownLoadEvent2):Boolean;
var
  thread:TThreadDownLoad;
begin
  Result := False;

  GStop := False;

  //if GHttpFileName_List = nil Then GHttpFileName_List := TStringList.Create;
  //GHttpFileName_List.Clear;

  //每次下 40 K
  thread := TThreadDownLoad.Create(True);
  thread.blockSize := 40 * 1024;
  thread.httpFileName := fn; //GHttpFileName_List_Fn; //Self.httpFileName;

  //版本信息文件经常改，所以不校验 md5 也不做断点
  if LowerCase(Trim(ExtractFileName(fn))) = GHttpFileName_Ver then
    DeleteFile(thread.GetLocalFileName); //这个文件无法校验，因此每次都取最新的。所以要先删除


  thread.OnDownComplete := OnDownComplete;//@On_GetHttpFile;

  thread.Resume;

end;

function CheckFile(fn, fn_before_zip:String; zip, zip_is_dir:Integer; md5, zip_md5:string):Boolean;
var
  _localFileName:String;
  _local_md5,_http_md5:String;
begin
  Result := False;

  _localFileName := fn;
  _http_md5 := md5;

  //if 1 = zip then
  if (1 = zip)and(zip_is_dir<>1) then
  begin
    _localFileName := fn_before_zip;
    _http_md5 := md5;
  end;
  _local_md5 := GetFileMd5(_localFileName);

  if _local_md5<>_http_md5 then  //文件内容不符合,要删除已下载的内容
  begin
    gFileMd5Error := True;

    DeleteFile(fn);
    DeleteFile(fn_before_zip);

    ShowMessage('发现不符合的文件。' + fn);

    Exit;  //文件内容不符合
  end;

  Result := True;
end;


//如果复制文件失败，先将原文件改名，在 windows 下是可以这样的
function _CopyFile(const SrcFilename, DestFilename: string):Boolean;
var
  r:Boolean;
  fn_bak:String;
begin
  //https://wiki.freepascal.org/CopyFile
  r := CopyFile(SrcFilename, DestFilename, [cffOverwriteFile]);

  if False = r then //如果复制失败，则先将先文件“移动”
  begin
    //修改后缀名
    fn_bak := ExtractFileNameWithoutExt(DestFilename)+ '[bak]' + ExtractFileExt(DestFilename);
    DeleteFile(fn_bak); //如果备份文件存在的话，后面的修改会失败
    RenameFile(DestFilename, fn_bak);

    //r := CopyFile(SrcFilename, fn_bak, [cffOverwriteFile]); //test
    r := CopyFile(SrcFilename, DestFilename, [cffOverwriteFile]);
  end;

  Result := r;
end;

{//目前用不着，复制过程还是统一的，跳过版本信息文件的校验就可以了

//版本信息文件直接复制不进行校验
procedure CopyFile_Ver();
var
  s:String;
  //sl:TStringList;
  path:String;
  fn, fn_info:String;


  down_file,app_file:String; //旧文件和新文件，下载的，程序本身的
  r:Boolean;
begin

    fn := GHttpFileName_Ver;

    fn := ExtractFilePath(Application.ExeName) + 'update_down\' + ExtractFileName(fn);


    //--------------------


    down_file := fn;

    app_file := ExtractFilePath(Application.ExeName) + ExtractFileName(down_file);

    //-----------
    //先删除，如果删除失败，有可能是权限不足

    r := _CopyFile(down_file, app_file);


end;
}

//全部校验成功才复制文件，因为文件批次间可能相互依赖
procedure CopyFileAll();
var
  s:String;
  sl,sl_del:TStringList;
  path:String;
  fn, fn_info:String;
  i,zip,zip_is_dir:Integer;
  md5,zip_md5,fn_before_zip:string; //信息文件中的各个内容
  //fn_before_zip:String; //压缩前的文件名

  down_file,app_file:String; //旧文件和新文件，下载的，程序本身的
  r:Boolean;
begin
  if gFileMd5Error = True then
  begin
    ShowMessage('有错误文件。');
    Exit;
  end
  else
  begin
    ShowMessage('所有文件全部正确下载，准备复制替换。请先退出主程序。');

  end;


  sl := TStringList.Create;
  sl_del := TStringList.Create;

  for i:=0 to GHttpFileName_List.Count-1 do
  begin
    fn := GHttpFileName_List.Strings[i];

    if Trim(fn) = '' then Continue;

    fn := ExtractFilePath(Application.ExeName) + 'update_down\' + ExtractFileName(fn);
    //fn_before_zip := fn;

    fn_info := fn + '.info.txt';

    //--------------------
    //信息文件中的信息
    sl.LoadFromFile(fn_info);

    //ShowMessage(sl.Text);

    zip := StrToIntDef(Trim(sl.Values['zip']), 0);      //是否是 zip 压缩的文件
    zip_is_dir := StrToIntDef(Trim(sl.Values['zip_is_dir']), 0);      //是否 zip 压缩的文件是一个目录
    md5 := Trim(sl.Values['md5']);                      //压缩前的 md5 值
    zip_md5 := Trim(sl.Values['zip_md5']);              //压缩后的 md5 值
    fn_before_zip := Trim(sl.Values['fn_before_zip']);  //压缩前的文件名

    //----
    fn_before_zip := ExtractFilePath(fn) + fn_before_zip;

    //if 1 = zip then
    //begin
    //  la_zip.UnZip(fn, ExtractFileDir(fn));
    //end;

    if 1 = zip_is_dir then
    begin
      //la_zip.UnZip(fn, ExtractFileDir(fn));
      la_zip.UnZip(fn, ExtractFileDir(Application.ExeName));
      r := True;
    end;

    //----
    //down_file,app_file:String; //旧文件和新文件，下载的，程序本身的
    //MakeLocalFileMd5(fn);
    //MakeLocalFileMd5(fn_before_zip);

    down_file := fn;
    if 1 = zip then down_file := fn_before_zip;

    app_file := ExtractFilePath(Application.ExeName) + ExtractFileName(down_file);

    //-----------
    //先删除，如果删除失败，有可能是权限不足
    //r := DeleteFile(app_file);

    //https://wiki.freepascal.org/CopyFile
    //r := _CopyFile(down_file, app_file, [cffOverwriteFile]);
    r := _CopyFile(down_file, app_file);
    sl_del.Add(down_file); //记录一下，后面删除

    if 1 = zip_is_dir then r := True;

    if False = r then
    begin
      ShowMessage('文件 ' + ExtractFileName(down_file) +' 复制失败，请退出主程序后再次尝试。');

      if GAutoDownFile then
      begin
        Application.ShowMainForm := True;
        if frmUpdateMain.Visible = False then frmUpdateMain.Show;
      end;

      Exit;
    end;

  end;



  ShowMessage('文件复制完毕。请重新启动程序。');

  //-----------------------------
  //全部复制完成后应该删除旧文件，因为下次版本更新时可能会因以有文件而不再下载，导致校验失败
  //似乎也不好，这样的话每次都要全新下载，如果文件比较大不合适，应该在下载完成时校验，不对的话立即重新下载
  for i:=0 to sl_del.Count-1 do
  begin
    //DeleteFile(sl_del.Strings[i]);
  end;

  //-----------------------------

  sl.Free;
  sl_del.Free;

  if (GAutoDownFile)and(frmUpdateMain.Visible = False) then
  begin
    ShowMessage('更新程序将退出。');
    Application.Terminate;
  end;

end;



//计算本地文件的 md5 值
procedure MakeLocalFileMd5_All();
var
  s:String;
  sl:TStringList;
  path:String;
  fn, fn_info:String;
  i,zip,zip_is_dir:Integer;
  md5,zip_md5,fn_before_zip:string; //信息文件中的各个内容
  //fn_before_zip:String; //压缩前的文件名
begin
  gFileMd5Error := False;

  sl := TStringList.Create;

  for i:=0 to GHttpFileName_List.Count-1 do
  begin
    fn := GHttpFileName_List.Strings[i];

    if Trim(fn) = '' then Continue;

    //版本信息文件不校验
    if GHttpFileName_Ver = LowerCase(Trim(ExtractFileName(fn))) then Continue;

    fn := ExtractFilePath(Application.ExeName) + 'update_down\' + ExtractFileName(fn);
    //fn_before_zip := fn;

    fn_info := fn + '.info.txt';

    //--------------------
    //信息文件中的信息
    //解压文件
    sl.LoadFromFile(fn_info);

    //ShowMessage(sl.Text);

    zip := StrToIntDef(Trim(sl.Values['zip']), 0);      //是否是 zip 压缩的文件
    zip_is_dir := StrToIntDef(Trim(sl.Values['zip_is_dir']), 0);      //是否 zip 压缩的文件是一个目录
    md5 := Trim(sl.Values['md5']);                      //压缩前的 md5 值
    zip_md5 := Trim(sl.Values['zip_md5']);              //压缩后的 md5 值
    fn_before_zip := Trim(sl.Values['fn_before_zip']);  //压缩前的文件名

    //----
    fn_before_zip := ExtractFilePath(fn) + fn_before_zip;

    if (1 = zip)and(zip_is_dir<>1) then
    begin
      la_zip.UnZip(fn, ExtractFileDir(fn));
    end;

    //----
    MakeLocalFileMd5(fn);
    MakeLocalFileMd5(fn_before_zip);

    //--------------------------------------------------------
    //检测，文件不对的话会删除，下次再次下载
    CheckFile(fn, fn_before_zip, zip, zip_is_dir, md5, zip_md5);

  end;

  sl.Free;

  //---- 校验完后再复制
  CopyFileAll();
end;

//计算本地文件的 md5 值
procedure MakeLocalFileMd5(fn:String);
var
  s:String;
  sl:TStringList;
  path:String;
  fn_md5:String;
begin

  if Trim(fn) = '' then Exit;

  s := GetFileMd5(fn);

  sl := TStringList.Create;
  sl.Text := s;

  path := ExtractFilePath(Application.ExeName) + 'update_down_md5\';
  fn_md5 := path + ExtractFileName(fn) + '.info.txt';

  ForceDirectories(path);

  sl.SaveToFile(fn_md5);

  sl.Free;
end;

end.

