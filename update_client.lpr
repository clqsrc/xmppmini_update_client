program update_client;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  uUpdateMain in 'uUpdateMain.pas' {frmUpdateMain},

  Forms, Dialogs,

  http_client, md5_check, la_zip;

{$R *.res}

var
  cmd_param:String;

begin
  //2020//
  cmd_param := ParamStr(1);
  //ShowMessage(cmd_param);

  if Pos('-hide', cmd_param)>0 then //如果是自动更新的命令行
  begin
    GAutoDownFile := True;
    Application.ShowMainForm := False;
  end;

  //------------------------

  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TfrmUpdateMain, frmUpdateMain);


  Application.Run;
end.

