unit la_functions;

//functions 的 lazarus 版本

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, windows;

//uses
//  Interfaces, //Lazarus 下出现 WSRegisterMenuItem 这些不存在的错误，就要把这个放到 Forms 单元之前//http://cache.baiducontent.com/c?m=9d78d513d98600b8599dd429584d96204e1497624c88874938c39238c8220c1e5321a3e52878564291846b6672b25408b7b0712d200357e9c880db0a9afa852858dc6763275ed500438047b8cb317881758d01b5f94eadadf045d1f490c4de201597115e2b97f1fd5f0312cb78f06333&p=c2769a47938611a05bef95284b59cd&newp=8a6cc64ad4934eac5aec8f6d534e86231615d70e3cd2d2176b82c825d7331b001c3bbfb423261a04d1c67f6606ab485ae0f23672320927a3dda5c91d9fb4c57479&user=baidu&fm=sc&query=WSRegisterMenuItem&qid=ef5ce66500001e1d&p1=1
//  Windows, ActiveX, ComObj, ShlObj, Classes, Dialogs, Forms;

//[2-4]Find_in_dir1的扩展，最后一个参数决定加入的是目录还是文件//路径、输出、是否查找子目录
procedure Find_in_dir1(path1:string;out1:tstringlist;sub1:boolean;type1:string);

//取得Dll自身路径
Function GetDllPath:string;

function Utf8ToAnsi_delphi7(s:string):string;
function AnsiToUtf8_delphi7(s:string):string;


implementation

uses
  LazUTF8;

//[2-4]Find_in_dir1的扩展，最后一个参数决定加入的是目录还是文件//路径、输出、是否查找子目录
procedure Find_in_dir1(path1:string;out1:tstringlist;sub1:boolean;type1:string);
var
  i_fr1: integer;//为了查找文件
  sr_fr1: TSearchRec;//for treeview2 为了查找文件

begin

  {查找文件目录}

  i_fr1 := FindFirst(path1+'*.*',faAnyFile, sr_fr1);
  while i_fr1 = 0 do
  begin
    if (sub1)and(DirectoryExists(path1+sr_fr1.Name+'\'))and(trim(sr_fr1.Name)<>'.')and(trim(sr_fr1.Name)<>'..') then
    begin
      //sr_fr1.Name
      Find_in_dir1(path1+sr_fr1.Name+'\',out1,sub1,type1);
    end;

    if type1='all' then
    begin
      if (sr_fr1.Name<>'..')and(sr_fr1.Name<>'.') then out1.Add(path1+sr_fr1.Name);

    end
    else
    if type1='dir' then
    begin//要得到的是目录
      if (sr_fr1.Name<>'..')and(sr_fr1.Name<>'.')and(DirectoryExists(path1+sr_fr1.Name)) then out1.Add(path1+sr_fr1.Name);
    end
    else//要得到的是文件
    if FileExists(path1+sr_fr1.Name) then out1.Add(path1+sr_fr1.Name);

    i_fr1 := FindNext(sr_fr1);
  end;
  //FindClose(sr_fr1);
  SysUtils.FindClose(sr_fr1); //实际上这是模拟 windows 的，所以引入了 windows 单元的话还要加 SysUtils 的限定

end;


//取得Dll自身路径
Function GetDllPath:string;
var
  ModuleName:string;
begin
  SetLength(ModuleName, 255);
  //取得Dll自身路径
  GetModuleFileName(HInstance, PChar(ModuleName), Length(ModuleName));

  Result := PChar(ModuleName);

  //似乎也可以用 GetModuleName //https://www.freepascal.org/docs-html/rtl/sysutils/getmodulename.html
end;

function Utf8ToAnsi_delphi7(s:string):string;
begin
  result := LazUTF8.UTF8ToWinCP(s);

end;

//lazarus 的 AnsiToUtf8 是无法转换 gbk 的 Ansi 的
//所以要有一个函数来得到与 delphi7 下同名函数效果的
function AnsiToUtf8_delphi7(s:string):string;
begin
  result := LazUTF8.WinCPToUTF8(s); //lazarus 的 AnsiToUtf8 是无法转换 gbk 的 Ansi 的 ;

  //这个指的是系统字符集，如果是确定为 gbk 的则要用 CP936ToUTF8 才好;
  //LConvEncoding,
  //LazUTF8,
end;

end.

