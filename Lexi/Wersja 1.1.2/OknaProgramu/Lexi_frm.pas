unit Lexi_frm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Imaging.pngimage,
  Vcl.ExtCtrls, System.Win.ComObj, Vcl.ExtDlgs, Vcl.Menus, Vcl.OleCtrls,
  MSHTML, SHDocVw, ClipBrd, IPPeerClient, REST.Client, Data.Bind.Components,
  Data.Bind.ObjectScope, System.JSON, REST.Json;

type
  TWindowsSpeech = class(TThread)
  private
    { Private declarations }
  protected
    procedure Execute; override;
    procedure DoOnTerminate(Sender: TObject);
  end;

type
  TLexi = class(TForm)
    img_lexi: TImage;
    twoja_wypowiedz: TEdit;
    WebBrowser1: TWebBrowser;
    AutoRun: TTimer;
    img_Lexi_def: TImage;
    img_Lexi_1: TImage;
    FaceChange: TTimer;
    RESTClient1: TRESTClient;
    RESTRequest1: TRESTRequest;
    RESTResponse1: TRESTResponse;
    TrayIcon1: TTrayIcon;
    Nasluch: TTimer;
    procedure twoja_wypowiedzKeyPress(Sender: TObject; var Key: Char);
    function Bez_polskich_znakow(tekst : String): String;
    procedure WebBrowser1DocumentComplete(ASender: TObject; const pDisp: IDispatch; const URL: OleVariant);
    function Z_wielkiej_litery(ciag : string) : String;
    procedure FormShow(Sender: TObject);
    procedure AutoRunTimer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FaceChangeTimer(Sender: TObject);
    function Analiza_kursu_waluty_NBP(dane: string): String;
    function Wartosc_XML(rekord: string): String;
    procedure TrayIcon1DblClick(Sender: TObject);
    procedure FormResize(Sender: TObject);

    procedure Analiza_wypowiedzi(wypowiedz_uzytkownika: String);

    procedure NasluchTimer(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    function Analiza_i_zamiana_tekstu(teskt_in: String): String;
  private
    { Private declarations }
  public
   procedure Czytaj_tekst(tekst : String);
   Var
    zamknac_po_zakonczeniu: Boolean;
    lektor_uruchomiony: Boolean;
    tekst_do_przeczytania_Lexi: String;

    imie_rozmowcy: string;
  end;

const
 wersja = '1.1.2';
var
  Lexi: TLexi;
  Speech : TWindowsSpeech;
  szukana_fraza : String;
  voice: OLEVariant;
  tab_zajawek: array[1..10] of String;
  byl_stan: Boolean;
  zrodlo: string;
  czy_bylo_uruchomienie: Boolean;
  tekst_nasluchu : TStringList;
  parametr_uruchomienia: string;

implementation

{$R *.dfm}
procedure TLexi.Czytaj_tekst(tekst : String);
Var
  voice: OLEVariant;
Begin
 Application.ProcessMessages;
 twoja_wypowiedz.Clear;
 tekst_do_przeczytania_Lexi:=tekst;
 Speech := TWindowsSpeech.Create(False);
End;

procedure TLexi.FaceChangeTimer(Sender: TObject);
Var
 czas : Integer;
begin
   if byl_stan=True then
    Begin
     img_lexi.Picture:=img_Lexi_1.Picture;
     byl_stan:=False;
     FaceChange.Interval:=5000;
    End
   else
    Begin
     img_lexi.Picture:=img_Lexi_def.Picture;
     byl_stan:=True;
     Randomize;
     czas:=Random(15)+5;
     czas:=czas*1000;
     FaceChange.Interval:=czas;
    End;
end;

procedure TLexi.FormCreate(Sender: TObject);
begin
 Caption  :='L.E.X.i';
 byl_stan :=True;
 zrodlo   :='wikipedia';
 czy_bylo_uruchomienie:=False;
 tekst_nasluchu :=TStringList.Create;
 tab_zajawek[1]:='o czym dziœ pogadamy?';
 tab_zajawek[2]:='co dziœ bêdziemy robiæ?';
 tab_zajawek[3]:='co Ciê dziœ interesuje?';
 tab_zajawek[4]:='nad czym dziœ popracujemy?';
 tab_zajawek[5]:='czego bêdziemy siê dziœ uczyæ?';
 tab_zajawek[6]:='co na dziœ masz w planach?';
 tab_zajawek[7]:='jakie rzczeczy dziœ bêdziemy omawiaæ?';
 tab_zajawek[8]:='zabierajmy siê do roboty.';
 tab_zajawek[9]:='co Ci dziœ chodzi po g³owie?';
 tab_zajawek[10]:='no to jazda - zaczynajmy.';
 parametr_uruchomienia:=ParamStr(1); //Pobieram parametry (dodatkowe polecenia wpisane po EXE)
end;

procedure TLexi.FormDestroy(Sender: TObject);
begin
 tekst_nasluchu.Free;
end;

procedure TLexi.FormResize(Sender: TObject);
begin
 if WindowState = wsMinimized then
  Begin
   Hide();
   TrayIcon1.Visible := True;
   TrayIcon1.ShowBalloonHint;
  End;
end;

procedure TLexi.FormShow(Sender: TObject);
begin
 if czy_bylo_uruchomienie=False then AutoRun.Enabled:=True;
end;

procedure TLexi.NasluchTimer(Sender: TObject);
var
 tekst : String;
begin
 tekst_nasluchu.Text:=Trim(Clipboard.AsText);
 if tekst_nasluchu.Count>0 then
 Begin
  tekst_nasluchu.Text:=AnsiLowerCase(tekst_nasluchu.Text);
  if Pos('lexi',tekst_nasluchu.Text)=1 then
  Begin
   Clipboard.Clear;
   tekst:=tekst_nasluchu.Text;
   Delete(tekst,1,5);
   tekst_nasluchu.Text:=Trim(tekst);
   Analiza_wypowiedzi(tekst_nasluchu.Text);
  End;
 End;
end;

procedure TLexi.TrayIcon1DblClick(Sender: TObject);
begin
 TrayIcon1.Visible := False;
 Show();
 WindowState := wsNormal;
 Application.BringToFront();
end;

procedure TLexi.Analiza_wypowiedzi(wypowiedz_uzytkownika: String);
var
  wypowiedz: string;
  powiedz: string;
  wypowiedz_full: string;
  tryb_wikipedii: Boolean;
  pozycja: Integer;
  polecenie_nadrzedne: Boolean;
  poz: Integer;
  jValue: TJSONValue;
Begin
 if lektor_uruchomiony then TerminateThread(Speech.Handle,0);
   tryb_wikipedii:=False;
   polecenie_nadrzedne:=False;

   wypowiedz_full:=Trim(AnsiLowerCase(wypowiedz_uzytkownika));
   wypowiedz:=Analiza_i_zamiana_tekstu(Bez_polskich_znakow(wypowiedz_uzytkownika));
   powiedz:='';

   if wypowiedz='czytaj' then //to jest polecenie nadrzêcne
    Begin
     wypowiedz:=Analiza_i_zamiana_tekstu(Trim(Clipboard.AsText));
     if wypowiedz<>'' then powiedz:=wypowiedz
     else powiedz:='Nie mam czego przeczytaæ ze schowka!';
     polecenie_nadrzedne:=True;
    End;

   if wypowiedz='skanuj schowek' then wypowiedz:='wlacz nasluch';
   if wypowiedz='wlacz nasluch schowka' then wypowiedz:='wlacz nasluch';
   if wypowiedz='wlacz nasluch' then //to jest polecenie nadrzêcne
    Begin
     Nasluch.Enabled:=True;
     powiedz:='Skanujê schowek systemowy w poszukiwaniu tekstu. Pamiêtaj by polecenia zaczyna³y siê od mojego imienia - Lexi!';
     polecenie_nadrzedne:=True;
    End;

   if wypowiedz='wylacz nasluch schowka' then wypowiedz:='wylacz nasluch';
   if wypowiedz='wylacz nasluch' then //to jest polecenie nadrzêcne
    Begin
     Nasluch.Enabled:=False;
     powiedz:='Przesta³am skanowaæ schowek.';
     polecenie_nadrzedne:=True;
    End;

  if polecenie_nadrzedne=False then
   Begin
   if wypowiedz='jak zmienic wyszukiwanie' then powiedz:='powiedz szukaj w pwn, lub szukaj w wikipedii';
   if wypowiedz='jak zmienic zrodlo wyszukiwania' then powiedz:='powiedz szukaj w pwn, lub szukaj w wikipedii';

   if (Pos('gdzie',wypowiedz)>0) AND (Pos('szukasz',wypowiedz)>0) AND (Pos('odpowiedzi',wypowiedz)>0) then powiedz:='Obecnie szukam odpowiedzi w bazach '+zrodlo+'. Mo¿esz to zmieniæ!';
   if (Pos('skad',wypowiedz)>0) AND (Pos('bierzesz',wypowiedz)>0) AND (Pos('odpowiedzi',wypowiedz)>0) then powiedz:='Obecnie szukam odpowiedzi w bazach '+zrodlo+'. Mo¿esz to zmieniæ!';

   if (Pos('jak',wypowiedz)>0) AND (Pos('masz',wypowiedz)>0) AND (Pos('imie',wypowiedz)>0) then powiedz:='Na imiê mam Lexi.';
   if (Pos('jak',wypowiedz)>0) AND (Pos('sie',wypowiedz)>0) AND (Pos('nazywasz',wypowiedz)>0) then powiedz:='Na imiê mam Lexi.';

   if (Pos('godzina',wypowiedz)>0) AND (Pos('ktora',wypowiedz)>0) then powiedz:='Teraz jest '+Copy(TimeToStr(Now),1,5);
   if (Pos('dzien',wypowiedz)>0) AND (Pos('dzis',wypowiedz)>0) then powiedz:='Dziœ jest '+DateToStr(Now);
   if (Pos('swoja',wypowiedz)>0) AND (Pos('podaj',wypowiedz)>0) AND (Pos('wersje',wypowiedz)>0) then powiedz:='Moja obecna wersja to '+wersja;
   if (Pos('jaka',wypowiedz)>0) AND (Pos('wersja',wypowiedz)>0) then powiedz:='Moja obecna wersja to '+wersja;

   if (Pos('czym',wypowiedz)>0) AND (Pos('jestes',wypowiedz)>0) then powiedz:='Jestem prototypem asystemta programów FX Systems!';
   if (Pos('kim',wypowiedz)>0) AND (Pos('jestes',wypowiedz)>0) then powiedz:='Jestem prototypem asystemta programów FX Systems!';

   if (Pos('cie',wypowiedz)>0) AND (Pos('napisal',wypowiedz)>0) then powiedz:='Jestem prototypem asystemta stworzonym przez firmê FX Systems!';
   if (Pos('cie',wypowiedz)>0) AND (Pos('stworzyl',wypowiedz)>0) then powiedz:='Jestem prototypem asystemta stworzonym przez firmê FX Systems!';

   if (Pos('co',wypowiedz)>0) AND (Pos('potrafisz',wypowiedz)>0) then wypowiedz:='?';
   if (Pos('co',wypowiedz)>0) AND (Pos('umiesz',wypowiedz)>0) then wypowiedz:='?';

   if (Pos('mam na imie',wypowiedz)>0) then
    Begin
     wypowiedz:=StringReplace(wypowiedz, 'mam na imie', '', [rfReplaceAll]);
     wypowiedz:=Trim(wypowiedz);
     imie_rozmowcy:=wypowiedz;
     powiedz:='Witaj '+imie_rozmowcy+'. Mi³o mi Ciê poznaæ. Ja jestem Lexi.';
    End;

   if (Pos('kurs',wypowiedz)=1) then wypowiedz:='jaki jest '+wypowiedz;

   if (Pos('podaj',wypowiedz)>0) AND (Pos('kurs',wypowiedz)>0) then wypowiedz:=StringReplace(wypowiedz,'podaj','jaki jest', [rfReplaceAll]);

   if (Pos('jaki',wypowiedz)>0) AND (Pos('jest',wypowiedz)>0) AND (Pos('kurs',wypowiedz)>0) then
    Begin
     if Pos('euro',wypowiedz)>0 then wypowiedz:=StringReplace(wypowiedz,'euro','eur',[rfReplaceAll]);
     if Pos('dolara amerykanskiego',wypowiedz)>0 then wypowiedz:=StringReplace(wypowiedz,'dolara amerykanskiego','usd',[rfReplaceAll]);
     if Pos('dolar amerykanski',wypowiedz)>0 then wypowiedz:=StringReplace(wypowiedz,'dolar amerykanski','usd',[rfReplaceAll]);

     poz:=Pos('kurs',wypowiedz);
     Delete(wypowiedz,1,poz+4); wypowiedz:=trim(wypowiedz);
     if Pos('?',wypowiedz)>0 then Delete(wypowiedz,Pos('?',wypowiedz),1);
     wypowiedz:=trim(wypowiedz);
     if length(wypowiedz)=3 then
      Begin
       RESTClient1.BaseURL:='http://api.nbp.pl/api/exchangerates/rates/A/'+AnsiUpperCase(wypowiedz);
       RESTRequest1.Execute;
       jValue:=RESTResponse1.JSONValue;
       powiedz:=Analiza_kursu_waluty_NBP(TJson.Format(jValue));
      End
     else powiedz:='Nie znam tej waluty. Musisz podaæ trzyliterowy skrót waluty';
    End;

   if Pos('szukaj w',wypowiedz)>0 then
    Begin
     wypowiedz:=StringReplace(wypowiedz,'szukaj w', '', [rfReplaceAll]);
     wypowiedz:=Trim(wypowiedz);
     if (wypowiedz='pwn') or (wypowiedz='wikipedii') or (wypowiedz='wikipedia') then
      Begin
       zrodlo:=wypowiedz;
       if zrodlo='pwn' then zrodlo:='pwn';
       if Pos('wiki',zrodlo)>0 then zrodlo:='wikipedia';
       powiedz:='Przyjê³am, od teraz bêdê szukaæ w '+zrodlo;
      End
     else powiedz:='Mo¿na wybraæ tylko bazy danych pwn, lub wikipedii';
    End;

   if (Pos('zamknij',wypowiedz)>0) AND (Pos('sie',wypowiedz)>0) then wypowiedz:='cicho';
   if (Pos('cicho',wypowiedz)>0) then powiedz:='ju¿ nic nie mówiê';

   if (Pos('czesc',wypowiedz)>0) then wypowiedz:='hi';
   if (Pos('witaj',wypowiedz)>0) then wypowiedz:='hi';
   if (Pos('siema',wypowiedz)>0) then wypowiedz:='hi';
   if (Pos('dzien',wypowiedz)>0) AND (Pos('dobry',wypowiedz)>0) then wypowiedz:='hi';
   if wypowiedz='hi' then
    Begin
     randomize;
     pozycja:=Random(9)+1;
     powiedz:='Czeœæ. '+tab_zajawek[pozycja];
    End;

   if (powiedz='') AND (Pos('co',wypowiedz)>0) AND (Pos('to',wypowiedz)>0) AND (Pos('jest',wypowiedz)>0) then
    Begin
     if zrodlo='' then powiedz:='Nie zosta³a podjêta decyzja gdzie mam szukaæ. Powiedz szukaj w pwn, lub szukaj w wikipedii'
     else
     Begin
     tryb_wikipedii:=True;
     wypowiedz_full:=StringReplace(wypowiedz_full,'co','',[rfReplaceAll]);
     wypowiedz_full:=StringReplace(wypowiedz_full,'to','',[rfReplaceAll]);
     wypowiedz_full:=StringReplace(wypowiedz_full,'jest','',[rfReplaceAll]);
     wypowiedz_full:=StringReplace(wypowiedz_full,'?','',[rfReplaceAll]);
     wypowiedz_full:=Trim(wypowiedz_full);
     szukana_fraza:=Z_wielkiej_litery(wypowiedz_full);
     if zrodlo='wikipedia' then
     WebBrowser1.Navigate('https://pl.wikipedia.org/w/api.php?action=query&titles='+szukana_fraza+'&prop=revisions&rvprop=content&format=xmlfm')
     else WebBrowser1.Navigate('http://encyklopedia.pwn.pl/szukaj/'+szukana_fraza);
     End;
    End;

   if (powiedz='') AND (Pos('co',wypowiedz)>0) AND (Pos('wiesz',wypowiedz)>0) AND (Pos('o',wypowiedz)>0) then
    Begin
     if zrodlo='' then powiedz:='Nie zosta³a podjêta decyzja gdzie mam szukaæ. Powiedz szukaj w pwn, lub szukaj w wikipedii'
     else
     Begin
     tryb_wikipedii:=True;
     wypowiedz_full:=StringReplace(wypowiedz_full,'co','',[rfReplaceAll]);
     wypowiedz_full:=StringReplace(wypowiedz_full,'wiesz','',[rfReplaceAll]);
     wypowiedz_full:=StringReplace(wypowiedz_full,'o','',[rfReplaceAll]);
     wypowiedz_full:=StringReplace(wypowiedz_full,'?','',[rfReplaceAll]);
     wypowiedz_full:=Trim(wypowiedz_full);
     szukana_fraza:=Z_wielkiej_litery(wypowiedz_full);
     if zrodlo='wikipedia' then
     WebBrowser1.Navigate('https://pl.wikipedia.org/w/api.php?action=query&titles='+szukana_fraza+'&prop=revisions&rvprop=content&format=xmlfm')
     else WebBrowser1.Navigate('http://encyklopedia.pwn.pl/szukaj/'+szukana_fraza);
     End;
    End;

   if (powiedz='') AND (Pos('czym',wypowiedz)>0) AND (Pos('jest',wypowiedz)>0) then
    Begin
     if zrodlo='' then powiedz:='Nie zosta³a podjêta decyzja gdzie mam szukaæ. Powiedz szukaj w pwn, lub szukaj w wikipedii'
     else
     Begin
     tryb_wikipedii:=True;
     wypowiedz_full:=StringReplace(wypowiedz_full,'czym','',[rfReplaceAll]);
     wypowiedz_full:=StringReplace(wypowiedz_full,'jest','',[rfReplaceAll]);
     wypowiedz_full:=StringReplace(wypowiedz_full,'?','',[rfReplaceAll]);
     wypowiedz_full:=Trim(wypowiedz_full);
     szukana_fraza:=Z_wielkiej_litery(wypowiedz_full);
     if zrodlo='wikipedia' then
     WebBrowser1.Navigate('https://pl.wikipedia.org/w/api.php?action=query&titles='+szukana_fraza+'&prop=revisions&rvprop=content&format=xmlfm')
     else WebBrowser1.Navigate('http://encyklopedia.pwn.pl/szukaj/'+szukana_fraza);
     End;
    End;

   if (wypowiedz='?') OR (wypowiedz='pomoc') OR (wypowiedz='help') then
    Begin
     powiedz:='Na chwilê obecn¹ moje zdolnoœci interakcji s¹ ograniczone.'+#13;
     powiedz:=powiedz+'Mo¿esz siê zapytaæ o mnie, lub o datê, czy godzinê!'+#13;
     powiedz:=powiedz+'Ciekawiej jednak sformuowaæ pytanie do internetowych encyklopedii!'+#13;
     powiedz:=powiedz+'Zapytaj co to i podaj s³owa kluczowe do analizy.'+#13;
     powiedz:=powiedz+'Mój twórca ca³y czas pracuje nad rozbudow¹ i ulepszeniem';
    End;

   if (wypowiedz='koniec') OR (wypowiedz='spadaj') then
    Begin
     voice := CreateOLEObject('SAPI.SpVoice');
     powiedz:='Ju¿ nie przeszkadzam!';
     voice.Speak(powiedz, 0);
     zamknac_po_zakonczeniu:=True;
    End;

   if (Pos('powiedz',wypowiedz)>0) and (powiedz='') then
    Begin
     wypowiedz_full:=StringReplace(wypowiedz_full,'powiedz','',[rfReplaceAll]);
     powiedz:=Trim(wypowiedz_full);
    End;
   End;

   if powiedz='' then powiedz:='Moje zdolnoœci interakcji s¹ ograniczone. Spróbuj zadaæ inne pytanie.';

   if (powiedz<>'') and (tryb_wikipedii=False) then Czytaj_tekst(powiedz);
End;

procedure TLexi.twoja_wypowiedzKeyPress(Sender: TObject; var Key: Char);

begin
 if Ord(Key)=13 then
  Begin
   Key := #0;
   Analiza_wypowiedzi(twoja_wypowiedz.Text);
  End;
end;

procedure TLexi.WebBrowser1DocumentComplete(ASender: TObject;
  const pDisp: IDispatch; const URL: OleVariant);
Var
  Document: IHtmlDocument2;
  schowek: string;
  poz: Integer;
  i: Integer;
  poczatek: Integer;
  znak: Char;
  czy_jest_podzial: Boolean;
  poz_podzialu: Integer;
  lista, lista_wyn: TStringList;
  linia: string;
begin
 Document := Webbrowser1.Document as IHTMLDocument2;
 schowek:=Trim(Document.body.innerText);
 schowek:=AnsiLowerCase(schowek);

 szukana_fraza:=AnsiLowerCase(szukana_fraza);

 if zrodlo='wikipedia' then
 Begin
 schowek:=StringReplace(schowek,'  ', ' ', [rfReplaceAll]);
 schowek:=StringReplace(schowek,' ''''''', '''''''', [rfReplaceAll]);

 if Pos('"preserve">#patrz',schowek)>0 then
  Begin
   poczatek:=Pos('#patrz',schowek);
   poz:=Pos('</rev>',schowek);
   schowek:=Trim(Copy(schowek,poczatek+6,poz-poczatek));
   schowek:=StringReplace(schowek,'</rev>','',[rfReplaceAll]);
   schowek:=StringReplace(schowek,']','',[rfReplaceAll]);
   schowek:=StringReplace(schowek,'[','',[rfReplaceAll]);
   schowek:='sugerujê poszukaæ '+schowek;
  End
 else
 Begin
 if Pos('"'+szukana_fraza+'" missing=""',schowek)>0 then
 schowek:=''
 else
  Begin
   if Pos('<ref>',schowek)>0 then
    Begin
     Repeat
      poczatek:=Pos('<ref>',schowek);
      poz:=0;
      for i := poczatek to Length(schowek) do
       Begin
        if (poz=0) and (schowek[i]='<') and (schowek[i+1]='/')
        and (schowek[1+2]='r') then poz:=i+5;
       End;
      Delete(schowek,poczatek,poz-poczatek+1);
     Until Pos('<ref>',schowek)=0;
    End;

   if Pos(''''''''+szukana_fraza+'''''''',schowek)>0 then
    Begin
     poz:=Pos(''''''''+szukana_fraza+'''''''',schowek);
     schowek:=Trim(Copy(schowek,poz,Length(schowek)));
    End;
   poz:=Pos('==',schowek);
   schowek:=Trim(Copy(schowek,1,poz-1));

   if Pos(']]',schowek)>0 then
    Begin
     Repeat
      poz:=Pos(']]',schowek);
      poczatek:=0;
      czy_jest_podzial:=False;
      for i := poz downto 1 do
       Begin
        znak:=schowek[i];
        if (znak='[') and (poczatek=0) then poczatek:=i;
        if (znak='|') and (poczatek=0) then
         Begin
          czy_jest_podzial:=True;
          poz_podzialu:=i;
         End;
       End;
      Delete(schowek,poz,1);
      if czy_jest_podzial=True then
       Begin
        Delete(schowek,poczatek,poz_podzialu-poczatek+1);
       End;
     Until Pos(']]',schowek)=0;
    End;

   if Pos('&',schowek)>0 then
    Begin
     Repeat
      poz:=Pos('&',schowek);
      Delete(schowek,poz,4);
     Until Pos('&',schowek)=0;
    End;

   if Pos('http:',schowek)>0 then
    Begin
     Repeat
      poczatek:=Pos('http:',schowek);
      poz:=0;
      for i := poczatek to Length(schowek) do
       Begin
        znak:=schowek[i];
        if (znak=' ') and (poz=0) then poz:=i;
       End;
      if poz=0 then Delete(schowek,poczatek,Length(schowek))
      else Delete(schowek,poczatek,poz-poczatek+1);
     Until Pos('http:',schowek)=0;
    End;

   schowek:=StringReplace(schowek,'''''''','',[rfReplaceAll]);
   schowek:=StringReplace(schowek,']','',[rfReplaceAll]);
   schowek:=StringReplace(schowek,'[','',[rfReplaceAll]);
   schowek:=StringReplace(schowek,'}','',[rfReplaceAll]);
   schowek:=StringReplace(schowek,'{','',[rfReplaceAll]);
   schowek:=StringReplace(schowek,'|','',[rfReplaceAll]);
   schowek:=StringReplace(schowek,'/ref.','',[rfReplaceAll]);
   schowek:=StringReplace(schowek,'/ref','',[rfReplaceAll]);

   if Length(schowek)>500 then
    Begin
     poczatek:=500;
     poz:=0;
     for i := poczatek to Length(schowek) do
      Begin
       znak:=schowek[i];
       if (znak='.') and (poz=0) then poz:=i;
      End;
      Delete(schowek,poz,Length(schowek));
    End;

  end;
 End;

 if Pos('wynik mediawiki api',schowek)>0 then schowek:='Nie umiem na to odpowiedzieæ. Sformuuj inaczej pytanie!';

 schowek:=Trim(schowek);
 End;

 if zrodlo='pwn' then
 Begin
  lista:=TStringList.Create;
  lista_wyn:=TStringList.Create;
  lista.Text:=schowek;
  for i := 0 to lista.Count-1 do
   Begin
    linia:=Trim(lista.Strings[i]);
    if linia<>'' then lista_wyn.Add(linia);
   End;

  lista.Clear;
  poczatek:=0;
  for i := 1 to lista_wyn.Count-1 do
   Begin
    linia:=lista_wyn.Strings[i];
    if (Pos(szukana_fraza,linia)>0)
    and (lista_wyn.Strings[i-1]='encyklopedia') and (poczatek=0)
    and (Pos('<!--// <![',lista_wyn.Strings[i+1])=0) then poczatek:=i;
    if poczatek>0 then lista.Add(linia);

   End;

  schowek:=lista.Text;
  lista.Free;
  lista_wyn.Free;

  poz:=Pos('<!--// <![cdata[',schowek);
  Delete(schowek,poz,Length(schowek));
  if Length(schowek)>500 then
    Begin
     poczatek:=500;
     poz:=0;
     for i := poczatek to Length(schowek) do
      Begin
       znak:=schowek[i];
       if (znak='.') and (poz=0) then poz:=i;
      End;
      Delete(schowek,poz,Length(schowek));
    End;
 End;

 if schowek<>'' then Czytaj_tekst(schowek)
 else Czytaj_tekst('Nie wiem czym jest '+szukana_fraza+' Zawsze mo¿esz zmieniæ Ÿrod³o moich danych. Powiedz szukaj w pwn, lub szukaj w wikipedii');
end;

procedure TLexi.AutoRunTimer(Sender: TObject);
begin
 AutoRun.Enabled:=False;
 czy_bylo_uruchomienie:=True;
 voice := CreateOLEObject('SAPI.SpVoice');
 if parametr_uruchomienia='' then
  voice.Speak('Jestem Lexi. W czym mogê pomóc?', 0)
 else voice.Speak(' ', 0);
 twoja_wypowiedz.Visible:=True;
 twoja_wypowiedz.SetFocus;
 Application.ProcessMessages;

 if parametr_uruchomienia='nasluch_schowka' then
  Begin
   Nasluch.Enabled:=True;
   WindowState:=wsMinimized;
  End;
end;

function TLexi.Bez_polskich_znakow(tekst : String): String;
Var
 wynik : String;
 dl, i : Integer;
 znak : Char;
Begin
 wynik:='';
 tekst:=Trim(AnsiLowerCase(tekst));
 dl:=Length(tekst);
  for i := 1 to dl do
   Begin
    znak:=tekst[i];
    if znak='¹' then znak:='a';
    if znak='ê' then znak:='e';
    if znak='ñ' then znak:='n';
    if znak='œ' then znak:='s';
    if znak='æ' then znak:='c';
    if znak='ó' then znak:='o';
    if znak='¿' then znak:='z';
    if znak='Ÿ' then znak:='z';
    if znak='³' then znak:='l';
    wynik:=wynik+znak;
   End;
 Bez_polskich_znakow:=wynik;
End;

function TLexi.Z_wielkiej_litery(ciag : string) : String;
var
  i: Integer;
Begin
 if Pos(' ',ciag)>0 then
  Begin
   for i := 1 to Length(ciag) do
    Begin
     if ciag[i]=' ' then ciag[i+1]:=UpCase(ciag[i+1]);
    End;
  End;
 Z_wielkiej_litery:=ciag;
End;

function TLexi.Wartosc_XML(rekord: string): String;
Var
 wynik: string;
 poz: Integer;
Begin
 wynik:='';
 rekord:=StringReplace(rekord,'"','',[rfReplaceAll]);
 poz:=Pos(':',rekord); Delete(rekord,1,poz);
 rekord:=Trim(rekord); Delete(rekord,Length(rekord),1);
 wynik:=rekord;
 Wartosc_XML:=wynik;
End;

function TLexi.Analiza_kursu_waluty_NBP(dane: string): String;
Var
  wynik : String;
  lista : TStringList;
  i : Integer;
  linia: string;
  waluta: string;
  kurs: string;
  datka: string;

Begin
 wynik:='';
 lista:=TStringList.Create;
 lista.Text:=dane;
 for i := 0 to lista.Count-1 do
  Begin
   linia:=AnsiLowerCase(Trim(lista.Strings[i]));
   if Pos('currency',linia)>0 then waluta:=Wartosc_XML(linia);
   if Pos('effectivedate',linia)>0 then datka:=Wartosc_XML(linia);
   if Pos('mid',linia)>0 then kurs:=Wartosc_XML(linia);
  End;
 wynik:=waluta+' kurs z dnia: '+datka+' wartoœæ NBP: '+kurs+' z³otego';
 lista.Free;
 Analiza_kursu_waluty_NBP:=wynik;
End;

function TLexi.Analiza_i_zamiana_tekstu(teskt_in: String): String;
Var
 wynik : String;
Begin
 wynik:='';
 teskt_in:=AnsiLowerCase(teskt_in);
 wynik:=StringReplace(teskt_in,'www','wuwuwu',[rfReplaceAll]);
 Analiza_i_zamiana_tekstu:=wynik;
End;

//####################################################################################
//          Czêœæ obs³uguj¹ca wielow¹tkowoœæ
//####################################################################################
procedure TWindowsSpeech.Execute;
begin
  FreeOnTerminate := True;
  OnTerminate :=  DoOnTerminate;
  Lexi.lektor_uruchomiony:=True;
  voice := CreateOLEObject('SAPI.SpVoice');
  voice.Speak(Lexi.tekst_do_przeczytania_Lexi, 1);
end;

procedure TWindowsSpeech.DoOnTerminate(Sender: TObject);
begin
  if Lexi.zamknac_po_zakonczeniu=True then Lexi.Close;
  Lexi.lektor_uruchomiony:=False;
  inherited;
end;
//####################################################################################
end.
