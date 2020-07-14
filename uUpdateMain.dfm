object frmUpdateMain: TfrmUpdateMain
  Left = 613
  Height = 257
  Top = 459
  Width = 625
  BorderIcons = [biSystemMenu, biMinimize]
  Caption = '更新程序 2020 v2'
  ClientHeight = 257
  ClientWidth = 625
  Color = clBtnFace
  Font.CharSet = ANSI_CHARSET
  Font.Color = clWindowText
  Font.Height = -14
  Font.Name = '宋体'
  OnCreate = FormCreate
  Position = poScreenCenter
  LCLVersion = '2.0.9.0'
  Scaled = False
  object ImagePanel1: TPanel
    Left = 0
    Height = 44
    Top = 0
    Width = 605
    ClientHeight = 44
    ClientWidth = 605
    TabOrder = 0
    object pnlCaptionRight: TPanel
      Left = 589
      Height = 44
      Top = 0
      Width = 201
      TabOrder = 0
    end
  end
  object pnlClient: TPanel
    Left = 0
    Height = 257
    Top = 0
    Width = 625
    Align = alClient
    BevelOuter = bvNone
    ClientHeight = 257
    ClientWidth = 625
    Color = 4210752
    Font.CharSet = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -14
    Font.Name = '宋体'
    ParentColor = False
    ParentFont = False
    TabOrder = 1
    object ProgressBar_DownLoad: TProgressBar
      Left = 17
      Height = 10
      Top = 104
      Width = 552
      TabOrder = 0
      Visible = False
    end
    object btnDownLoad: TPanel
      Left = 390
      Height = 27
      Top = 156
      Width = 88
      BevelOuter = bvNone
      Caption = '下载'
      Color = 15132390
      ParentColor = False
      TabOrder = 1
      OnClick = btnDownLoadClick
    end
    object Panel1: TPanel
      Left = 494
      Height = 27
      Top = 156
      Width = 88
      BevelOuter = bvNone
      Caption = '停止'
      Color = 15132390
      ParentColor = False
      TabOrder = 2
      OnClick = btnStopClick
    end
    object btnUpdate: TPanel
      Left = 286
      Height = 27
      Top = 156
      Width = 88
      BevelOuter = bvNone
      Caption = '更新'
      Color = 15132390
      ParentColor = False
      TabOrder = 3
      OnClick = btnUpdateClick
    end
    object Image1: TPanel
      Left = 17
      Height = 18
      Top = 66
      Width = 565
      BevelOuter = bvNone
      ClientHeight = 18
      ClientWidth = 565
      Color = clGray
      ParentColor = False
      TabOrder = 4
      object Image2: TPanel
        Left = 0
        Height = 18
        Top = 0
        Width = 369
        BevelOuter = bvNone
        Color = clWhite
        ParentColor = False
        TabOrder = 0
      end
    end
    object btnUpdate1: TPanel
      Left = 286
      Height = 27
      Top = 192
      Width = 88
      BevelOuter = bvNone
      Caption = 'un zip'
      Color = 15132390
      ParentColor = False
      TabOrder = 5
      Visible = False
      OnClick = btnUpdate1Click
    end
    object txtInfo: TLabel
      Left = 19
      Height = 14
      Top = 32
      Width = 49
      Caption = 'txtInfo'
      Font.CharSet = ANSI_CHARSET
      Font.Color = clWhite
      Font.Height = -14
      Font.Name = '宋体'
      ParentColor = False
      ParentFont = False
    end
    object btnUpdate2: TPanel
      Left = 390
      Height = 27
      Top = 192
      Width = 88
      BevelOuter = bvNone
      Caption = 'md5 file'
      Color = 15132390
      ParentColor = False
      TabOrder = 6
      Visible = False
      OnClick = btnUpdate2Click
    end
  end
  object OpenDialog1: TOpenDialog
    left = 116
    top = 133
  end
end
