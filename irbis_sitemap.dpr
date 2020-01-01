program IrbisSitemap;

{$APPTYPE CONSOLE}

uses
  Windows, SysUtils, WinSock, classes, inifiles, IdURI;


var
  WWSAData: TWSAData;
  WSocket: TSocket;
  WSockAddr: TSockAddr;
  Buf: Array of Char;
  Str: String;
  Size, BufSize: Integer;

  DeBug : Boolean;

  SiteMapFile : TStringList;

  cmdnom : Integer;
  ClientID : string;

  ServerIP : string;
  ServerPort : string;
  UserName : string;
  UserPassword : string;
  DBS : string;
  DBList : TStringList;

  MaxURLInFile : LongInt;
  SiteMapIndexPrefix : string;
  PathToSave : string;

procedure ReadINI();
var
  Ini: Tinifile;
begin
  Ini:=TiniFile.Create(extractfilepath(paramstr(0))+'irbis_sitemap.ini');

  DeBug := Ini.ReadBool('MAIN','DeBug',False);
  //DeBug := True;

  ServerIP := Ini.ReadString('MAIN','ServerIP','127.0.0.1');
  ServerPort := Ini.ReadString('MAIN','ServerPort','6666');
  UserName := Ini.ReadString('MAIN','UserName','1');
  UserPassword := Ini.ReadString('MAIN','UserPassword','1');
  dbs := Ini.ReadString('MAIN','dbs','ibis');
  MaxURLInFile:= StrToInt64(Ini.ReadString('MAIN','MaxURLInFile','50000'));
  SiteMapIndexPrefix := Ini.ReadString('MAIN','SiteMapIndexPrefix','http://localhost/');
  PathToSave := Ini.ReadString('MAIN','PathToSave','/');

  if Pos(',',DBS) = 0 then
    DBList.Text := dbs
  else
  begin
    DBList.Delimiter     := ',';
    DBList.DelimitedText := dbs;
  end;

end;



procedure Init();
begin
  SiteMapFile := TStringList.Create;
  DBList := TStringList.Create;

  CmdNom := 1;
  ClientID := '2344234';
  //MaxURLInFile := 100;
  ReadINI();
end;



function ReadFromSocket(socket: TSocket): String;
var
 _buff: array [0..255] of Char;
 _Str:AnsiString;
 _ret:integer;
begin
 fillchar(_buff, sizeof(_buff), 0);
 Result:='';
 _ret := recv(socket, _buff, 1024, 0);
 if _ret = -1 then
 begin
  Result:='';
  Exit;
 end;
 _Str := _buff;
 while pos(#13, _str)>0 do
 begin
  Result := Result+Copy(_str, 1, pos(#13, _str));
  Delete(_str, 1, pos(#13, _Str)+1);
 end;
end;


function SendCommand(request: string) : string;
var
  response : TStringList;
  tag, Count : Integer;
begin
  CmdNom := CmdNom + 1;
  response := TStringList.Create;

  if WSAStartup($101, WWSAData) <> 0 then Halt;
  WSocket := Socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
  if WSocket = INVALID_SOCKET then
  begin
    WriteLn('INVALID_SOCKET');
    //Код ошибки можно узнать, вызвав функцию WSAGetLastError.
    Halt;
  end;


  FillChar(WSockAddr, SizeOf(TSockAddr), 0);
  WSockAddr.sin_family := AF_INET;
  WSockAddr.sin_port := htons(StrToInt(ServerPort));
  WSockAddr.sin_addr.s_addr := inet_addr(PChar(ServerIP));
  if Connect(WSocket, WSockAddr, SizeOf(TSockAddr)) = SOCKET_ERROR then
  begin
    WriteLn('SOCKET_ERROR');
    Halt;
  end;


  Size := SizeOf(Integer);
  GetSockOpt(WSocket, SOL_SOCKET, SO_RCVBuf, @BufSize, Size);
  SetLength(Buf, BufSize);

  //Buf := @request;

  if Send(WSocket, request[1], Length(request), 0) = SOCKET_ERROR then
  begin
    WriteLn('SOCKET_ERROR');
    Halt;
  end;

  //Size := Recv(WSocket, Buf[0], BufSize, 0);
  //if Size <= 0 then Halt;
  //SetLength(response, Size);
  //lstrcpyn(@response[1], @Buf[0], Size + 1);



  while true do
  begin
    try
      Size := Recv(WSocket, Buf[0], BufSize, 0);
      response.Text := Copy(response.Text,0,Length(response.Text)-2) + Copy(PChar(Buf),0,Size);
      if Size <= 0 then
        break;
    except
        WriteLn('Неизвестная ошибка');
    end;
  end;



  CloseSocket(WSocket);
  WSACleanup;

  if DeBug then
  begin
    Writeln('=================== START Request ===================');
    Writeln(request);
    Writeln('=================== FINISH Request ===================');
    Writeln('=================== START Response ===================');
    Writeln(response.text);
    Writeln('=================== FINISH Response ===================');
  end;


  Result := response.Text;
  response.Free;
end;





function Registration() : string;
var
  request, response : string;
begin
  request := 'A' + #10 +
         'C' + #10 +
         'A' + #10 +
         ClientID + #10 +
         IntToStr(CmdNom) + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         UserPassword + #10 +
         UserName;
  request := inttostr(Length(request)) + #10 + request;
  response := SendCommand(request);
  //Result := response;
end;




function UnRegistration() : string;
var
  request, response : string;
begin
  request := 'B' + #10 +
         'C' + #10 +
         'B' + #10 +
         ClientID + #10 +
         IntToStr(CmdNom) + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         UserName;
  request := inttostr(Length(request)) + #10 + request;
  response := SendCommand(request);
  //Result := response;
end;





function RequestMaxMFN(DB : string) : string;
var
  request  : string;
  response : TStringList;
begin
  response := TStringList.Create;

  request := 'O' + #10 +
         'C' + #10 +
         'O' + #10 +
         ClientID + #10 +
         IntToStr(CmdNom) + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         DB;
  request := inttostr(Length(request)) + #10 + request;
  response.Text := SendCommand(request);

  Result := response[10];
  response.Free;
end;





function ReadRecordsID(DB : string; MFN : LongInt) : string;
var
  request, RecordsID  : string;
  response : TStringList;
  i : Integer;
begin
  response := TStringList.Create;
  RecordsID := '';

  request := 'C' + #10 +
         'C' + #10 +
         'C' + #10 +
         ClientID + #10 +
         IntToStr(CmdNom) + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         DB + #10 +
         IntToStr(MFN) + #10 +
         '0';

  request := inttostr(Length(request)) + #10 + request;
  response.Text := SendCommand(request);

  if response[10] = '0' then
  begin
    for i := 13 to response.count - 1 do
      if Copy(response[i], 1, 4) = '903#' then
      begin
        RecordsID := Copy(response[i], 5, Length(response[i]) - 4);
        Break;
      end;
  end;

  Result := RecordsID;
  response.Free;
end;




function RecordFormatting(DB : string; MFN : LongInt; Format : string) : string;
var
  request : string;
  response : TStringList;
  i : Integer;
begin
  response := TStringList.Create;

  request := 'G' + #10 +
         'C' + #10 +
         'G' + #10 +
         ClientID + #10 +
         IntToStr(CmdNom) + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         DB + #10 +
         Format + #10 +
         IntToStr(MFN);

  request := inttostr(Length(request)) + #10 + request;
  response.Text := SendCommand(request);

  if (response[10] = '0') and (response.Count > 10) then
  begin
    for i := 0 to 10 do
      response.Delete(0);
    for i := 0 to response.Count - 1 do
      response[i] := Copy(
                          response[i],
                          Pos('#',response[i]) + 1,
                          Length(response[i])
                         );

    Result := response.Text;
  end
  else
    Result := '';

    i :=  response.Count;
  response.Free;
end;


function FormatedAllRecord(DB : string) : string;
var
  request, RecordsID  : string;
  response : TStringList;
  i : Integer;
begin
  response := TStringList.Create;
  RecordsID := '';
         
  request := 'G' + #10 +
         'C' + #10 +
         'G' + #10 +
         ClientID + #10 +
         IntToStr(CmdNom) + #10 +
         UserPassword + #10 +
         UserName + #10 +
         '' + #10 +
         '' + #10 +
         '' + #10 +
         DB + #10 +
         '@tab_sitemap' + #10 +
         '0' + #10 +
         '0' + #10 +
         '0';

  request := inttostr(Length(request)) + #10 + request;
  response.Text := SendCommand(request);
  response.SaveToFile('FormatedAllRecord_' + DB + '_0.txt');


  i := response.Count;
  for i:=0 to 10 do
    response.Delete(0);
  i := response.Count;
  //response.SaveToFile('FormatedAllRecord_' + DB + '_1.txt');
  Result := response.Text;
  response.Free;
end;




procedure PrintToLog(str : string);
begin

end;



 // ============================================
 //
 //   Создание сайтмапа по списку баз данных.
 //   Каждая запись в отдельности прочитывается, и добавляется в список УРЛов
 //
 // ============================================
procedure CreateSiteMap_v1();
var
  DBNum, i : Integer;
  MaxMFNCurrentDB : LongInt;
  CurrentMFN : LongInt;
  PacketNum : LongInt;
  RecordsURL : TStringList;
  XMLBuf : TStringList;
  FormatedDay : string;
  SiteMapNumFile : Integer;
begin
  XMLBuf := TStringList.Create;
  RecordsURL := TStringList.Create;
  FormatedDay := FormatDateTime('yyyy-mm-dd',Now);


  //Регистрация на сервере Ирбиса
  Registration();

  //Цикл по списку баз данных
  for DBNum := 0 to DBList.Count - 1 do
  begin
    RecordsURL.text := RecordFormatting(DBList[DBNum], CurrentMFN, '@tab_sitemap');
    if RecordsURL.Count > 0 then
    begin
      //Добавить в сайтмап
      SiteMapFile.Text := SiteMapFile.Text + RecordsURL.text;
    end;
  end;

  //Разрегистрация на сервере Ирбиса
  UnRegistration();


  //Если ссылок меньше MaxURLInFile, то просто обрамляем тегами и сохраняем
  if SiteMapFile.Count - 1 < MaxURLInFile then
  begin
    XMLBuf.Text := '<?xml version="1.0" encoding="UTF-8"?>' + #10 +
                   '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + #10 +
                   SiteMapFile.Text  + #10 +
                   '</urlset> ';
    XMLBuf.SaveToFile(PathToSave + 'sitemap.xml');
  end;

  //Если ссылок больше MaxURLInFile, то бьем на кусочки по MaxURLInFile штук и сохраняем в отдельные файлы
  if SiteMapFile.Count - 1 > MaxURLInFile then
  begin

    SiteMapNumFile := 0;

    for i := 0 to SiteMapFile.Count - 1 do
    begin
      XMLBuf.Add(SiteMapFile[i]);
      PacketNum := PacketNum + 1;

      if (PacketNum = MaxURLInFile) or (i = SiteMapFile.Count - 1) then
      begin
        XMLBuf.Text := '<?xml version="1.0" encoding="UTF-8"?>' + #10 +
                   '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + #10 +
                   XMLBuf.Text  + #10 +
                   '</urlset> ';
        XMLBuf.SaveToFile(PathToSave + 'sitemap' + IntToStr(SiteMapNumFile) + '.xml');
        XMLBuf.Clear;
        PacketNum := 0;
        
        SiteMapNumFile := SiteMapNumFile + 1;
      end;
    end;


    XMLBuf.Clear;
    for i := 0 to SiteMapNumFile - 1 do
    begin
      XMLBuf.Add('<sitemap>' + #10 +
                 '<loc>' + SiteMapIndexPrefix + 'sitemap' + IntToStr(i) + '.xml</loc>' + #10 +
                 '<lastmod>' + FormatedDay + '</lastmod>' + #10 +
                 '</sitemap>');
    end;

    XMLBuf.Text := '<?xml version="1.0" encoding="UTF-8"?>' + #10 +
                   '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + #10 +
                   XMLBuf.Text + #10 +
                   '</sitemapindex>';
    XMLBuf.SaveToFile(PathToSave + 'sitemap.xml');

  end;


  RecordsURL.Free;
  XMLBuf.Free;

end;







procedure CreateSiteMap_v2();
var
  DBNum, i : Integer;
  MaxMFNCurrentDB : LongInt;
  CurrentMFN : LongInt;
  PacketNum : LongInt;
  RecordsURL : TStringList;
  XMLBuf : TStringList;
  FormatedDay : string;
  SiteMapNumFile : Integer;
begin
  XMLBuf := TStringList.Create;
  RecordsURL := TStringList.Create;
  FormatedDay := FormatDateTime('yyyy-mm-dd',Now);
  SiteMapFile.Text := '';

  //Регистрация на сервере Ирбиса
  Registration();

  //Цикл по списку баз данных
  for DBNum := 0 to DBList.Count - 1 do
  begin
    RecordsURL.text := RecordFormatting(DBList[DBNum], CurrentMFN, '@tab_sitemap_txt');
    if RecordsURL.Count > 0 then
    begin
      //Добавить в сайтмап
      SiteMapFile.Text := SiteMapFile.Text + RecordsURL.text;
    end;
  end;

  //Разрегистрация на сервере Ирбиса
  UnRegistration();


  //Если ссылок меньше MaxURLInFile, то просто обрамляем тегами и сохраняем
  if SiteMapFile.Count - 1 < MaxURLInFile then
    SiteMapFile.SaveToFile(PathToSave + 'sitemap.txt');



  //Если ссылок больше MaxURLInFile, то бьем на кусочки по MaxURLInFile штук и сохраняем в отдельные файлы
  if SiteMapFile.Count - 1 > MaxURLInFile then
  begin
    SiteMapNumFile := 0;

    for i := 0 to SiteMapFile.Count - 1 do
    begin
      XMLBuf.Add(SiteMapFile[i]);
      PacketNum := PacketNum + 1;

      if (PacketNum = MaxURLInFile) or (i = SiteMapFile.Count - 1) then
      begin
        XMLBuf.SaveToFile(PathToSave + 'sitemap' + IntToStr(SiteMapNumFile) + '.txt');
        XMLBuf.Clear;
        PacketNum := 0;
        
        SiteMapNumFile := SiteMapNumFile + 1;
      end;
    end;


    XMLBuf.Clear;
    for i := 0 to SiteMapNumFile - 1 do
    begin
      XMLBuf.Add(SiteMapIndexPrefix + 'sitemap' + IntToStr(i) + '.txt');
    end;


    XMLBuf.SaveToFile(PathToSave + 'sitemap.txt');

  end;


  RecordsURL.Free;
  XMLBuf.Free;

end;





begin
  Init();
  CreateSiteMap_v1();
  CreateSiteMap_v2();
end.
