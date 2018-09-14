program L.E.Xi;

uses
  Vcl.Forms,
  Lexi_frm in 'OknaProgramu\Lexi_frm.pas' {Lexi},
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'L.E.X.i';
  TStyleManager.TrySetStyle('Carbon');
  Application.CreateForm(TLexi, Lexi);
  Application.Run;
end.
