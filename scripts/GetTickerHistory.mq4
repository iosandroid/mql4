#property show_inputs

extern string SourceNum_Description = "0 - NASDAQ, 1 - Yahoo, 2 - Google";
extern int SourceNum = 0;
extern string TickerName = "AA";
extern string TickersList = ""; // TickersList_SP500.txt
extern string FileName = "Data.txt";

#import "wininet.dll"
  int InternetOpenA( string sAgent, int lAccessType, string sProxyName, string sProxyBypass, int lFlags );
  int InternetOpenUrlA( int hInternetSession, string sUrl, string sHeaders, int lHeadersLength, int lFlags, int lContext );
  int InternetReadFile( int hFile, int& lpvBuffer[], int lNumBytesToRead, int& lNumberOfBytesRead[] );
  int InternetCloseHandle( int hInet );
  int InternetQueryDataAvailable( int hFile, int& lpdwNumberOfBytesAvailable[], int dwFlags, int dwContext );
  int HttpQueryInfoA(int hRequest, int dwInfoLevel, int& lpvBuffer[], int& lpdwBufferLength[], int& lpdwReserved[] );
#import

#define HTTP_QUERY_CONTENT_LENGTH 0x00000005
#define HTTP_QUERY_FLAG_NUMBER    0x20000000

#define INTERNET_OPEN_TYPE_PRECONFIG    0x00000000   // use registry configuration
#define INTERNET_FLAG_RELOAD            0x80000000
#define INTERNET_FLAG_NO_CACHE_WRITE    0x04000000
#define INTERNET_FLAG_PRAGMA_NOCACHE    0x00000100

#define AGENT "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; Q312461)"

#define SIZEOF_INT 4

#define AMOUNT_DATA 6
#define AMOUNT_SOURCE 3
#define AMOUNT_MONTHS 12

#define MAX_AMOUNT_TICKERS 10000

string SourceName[AMOUNT_SOURCE] = {"NASDAQ", "Yahoo! Finance", "Google Finance"};
string PostFix[AMOUNT_SOURCE] = {"n", "y", "g"};
string URLS[AMOUNT_SOURCE] = {"http://charting.nasdaq.com/ext/charts.dll?2-1-14-0-0,0,0,0,0-5999-03NA000000[TICKERNAME]-&SF:4|5-WD=539-HT=395--XXCL-",
                              "http://ichart.finance.yahoo.com/table.csv?s=[TICKERNAME]",
                              "http://www.google.com/finance/historical?q=[TICKERNAME]&startdate=Jan+1%2C+1970&Jan+1%2C+3000&output=csv"};
// "http://stooq.com.ua/q/d/l/?s=[TICKERNAME]&d1=19700101&d2=30000101&i=d"
string Delimeters[AMOUNT_SOURCE] = {"", ",", ","};

int GetFileSize( int hRequest )
{
   int BufferLen[1] = {4};
   int Reserved[1] = {0};
   int Res, Buffer[1];

   Res =HttpQueryInfoA(hRequest, HTTP_QUERY_FLAG_NUMBER | HTTP_QUERY_CONTENT_LENGTH, Buffer, BufferLen, Reserved);

   if (Res != 0)
     Res = Buffer[0];

   return(Res);
}

int GetDataAvailable( int hRequest )
{
   int Res, Buffer[1];

   Res = InternetQueryDataAvailable(hRequest, Buffer, 0, 0);

   if (Res != 0)
     Res = Buffer[0];

   return(Res);
}

void SetComment( int Ready, int Full, int TimeInterval, string TickerName )
{
  string Str = WindowExpertName() + ": ACTIVE\n";
  string Procent = "Unknown ", FullStr = "Unknown";

  Str = Str + "Downloading \"" + TickerName + "\" from " + SourceName[SourceNum] + ".\n";

  Ready /= 1024;
  Full /= 1024;

  if (Full != 0)
  {
    Procent = DoubleToStr(100.0 * Ready / Full, 1);
    FullStr = Full;
  }

  if (TimeInterval != 0)
    Str = Str + Ready + " / " + FullStr + " Kb   (" + Procent + " %)   " +
          DoubleToStr(Ready * 1000.0 / TimeInterval, 1) + " Kb/s.\n";
  else
    Str = Str + Ready + " / " + FullStr + " Kb   (" + Procent + "%)   0 Kb/s.\n";

  Str = Str + "Elapsed time: " + TimeToStr(TimeInterval / 1000, TIME_SECONDS) + "\n";

  if ((Full != 0) && (Ready != 0))
    Str = Str + "Remaining time: " + TimeToStr(1.0 * (Full - Ready) * TimeInterval / (1000 * Ready), TIME_SECONDS);
  else
    Str = Str + "Remaining time: Unknown";

  Comment(Str);

  return;
}

bool HTTPToFile( int hSession, string strUrl, string FileName, string TickerName )
{
  int lReturn[1], Buffer[];
  int AvailableData, BufferSize;
  int StartTime, HTTPSize, ReadSize = 0;
  int handle, Tmp;
  string Str;
  int hReq = InternetOpenUrlA(hSession, strUrl, "", 0, INTERNET_FLAG_NO_CACHE_WRITE | INTERNET_FLAG_PRAGMA_NOCACHE | INTERNET_FLAG_RELOAD, 0);

  if (hReq == 0)
    return(FALSE);

  HTTPSize = GetFileSize(hReq);

  handle = FileOpen(FileName, FILE_BIN|FILE_WRITE);

  StartTime = GetTickCount();

  while (!IsStopped())
  {
    AvailableData = GetDataAvailable(hReq);

    if (AvailableData == 0)
      break;

    BufferSize = AvailableData / SIZEOF_INT;

    if (AvailableData % SIZEOF_INT > 0)
      BufferSize++;

    ArrayResize(Buffer, BufferSize);

    if (InternetReadFile(hReq, Buffer, AvailableData, lReturn) <= 0 || lReturn[0] == 0)
      break;

    FileWriteArray(handle, Buffer, 0, lReturn[0] / SIZEOF_INT);

    BufferSize = lReturn[0] % SIZEOF_INT;

    if (BufferSize > 0)
    {
      Tmp = Buffer[lReturn[0] / SIZEOF_INT];
      Str = "";

      while (BufferSize > 0)
      {
        Str = Str + CharToStr(Tmp & 0xFF);

        Tmp >>= 8;

        BufferSize--;
      }

      FileWriteString(handle, Str, StringLen(Str));
    }

    ReadSize += lReturn[0];

    SetComment(ReadSize, HTTPSize, GetTickCount() - StartTime, TickerName);
  }

  StartTime = GetTickCount() - StartTime;

  if (StartTime != 0)
    Print("Ticker \"" + TickerName + "\" is downloaded: " + DoubleToStr(ReadSize / 1024.0, 1) +
          " Kb (" + DoubleToStr(1000.0 / 1024 * ReadSize / StartTime, 1) + " Kb/s)");

  FileClose(handle);

  InternetCloseHandle(hReq);

  Comment(WindowExpertName() + ": ACTIVE");


  return(TRUE);
}

string GetStringBeforeDelimeter( string& Str, string Delimeter )
{
  string StrRes = Str;
  int Pos = StringFind(Str, Delimeter);

  if (Pos >= 0)
  {
    StrRes = StringSubstr(Str, 0, Pos);

    Str = StringSubstr(Str, Pos + 1);
  }

  return(StrRes);
}

int GetStrData( string Str, string Delimeter, string& StrData[] )
{
  int Count = 0;
  int Pos = StringFind(Str, Delimeter);

  while ((Pos >= 0) || (StringLen(Str) > 0))
  {
    StrData[Count] = StringSubstr(Str, 0, Pos);
    Count++;

    if (Count == AMOUNT_DATA)
      break;

    Str = StringSubstr(Str, Pos + 1);

    Pos = StringFind(Str, Delimeter);
  }

  return(Count);
}

void Parsing( string Str, double& DataBar[], int SourceNum )
{
  static string Months[AMOUNT_MONTHS] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
  static string StrData[AMOUNT_DATA];
  double Tmp;
  int i = 0, Count = GetStrData(Str, Delimeters[SourceNum], StrData);
  string StrTmp;

  Str = StrData[0];

  switch (SourceNum)
  {
    case 0: // NASDAQ
      StrData[0] = GetStringBeforeDelimeter(Str, "/");
      StrData[0] = StrData[0] + "." + GetStringBeforeDelimeter(Str, "/");
      StrData[0] = GetStringBeforeDelimeter(Str, "/") + "." + StrData[0];

      Str = StrData[5];
      ChangeString(Str, ",", "");
      StrData[5] = Str;

      break;
    case 1: // Yahoo! Finance
      ChangeString(Str, "-", ".");
      StrData[0] = Str;

      break;
    case 2: // Google Finance
      StrData[0] = GetStringBeforeDelimeter(Str, "-");
      StrTmp = GetStringBeforeDelimeter(Str, "-");

      while (StrTmp != Months[i])
        i++;

      i++;

      StrData[0] = i + "." + StrData[0];

      StrTmp = GetStringBeforeDelimeter(Str, "-");

      if (StrToInteger(StrTmp) < 30)
        StrTmp = "20" + StrTmp;
      else
        StrTmp = "19" + StrTmp;

      StrData[0] = StrTmp + "." + StrData[0];

      break;
  }

  DataBar[0] = StrToTime(StrData[0]);

  for (i = 1; i < Count; i++)
    DataBar[i] = StrToDouble(StrData[i]);

  Tmp = DataBar[ArrayMaximum(DataBar, AMOUNT_DATA - 2, 1)];
  DataBar[2] = DataBar[ArrayMinimum(DataBar, AMOUNT_DATA - 2, 1)];
  DataBar[3] = Tmp;

  return;
}

int FileToStrings( string FileName, string& Strings[] )
{
  bool FlagOnline;
  int i, Amount = 0;
  string Str;
  int handle = FileOpen(FileName, FILE_CSV|FILE_READ);

  while (!FileIsEnding(handle))
  {
    Str = FileReadString(handle);

    if (Amount == 1)
      FlagOnline = (StringFind(Str, ":") >= 0);
    else if (Amount == 0)
      if (StringFind(Str, "Volume") < 0)
        break;

    if (StringLen(Str) == 0)
      break;

    Amount++;
  }

  Amount--;

  if (FlagOnline)
    Amount--;

  if (Amount > 0)
  {
    ArrayResize(Strings, Amount);

    FileSeek(handle, 0, SEEK_SET);

    FileReadString(handle);

    if (FlagOnline)
      FileReadString(handle);

    for (i = 1; i <= Amount; i++)
      Strings[Amount - i] = FileReadString(handle);
  }

  FileClose(handle);

  return(Amount);
}

void ChangeString( string& StrBasic, string StrSource, string StrTarget )
{
  int Len = StringLen(StrSource);
  int Pos = StringFind(StrBasic, StrSource);

  while (Pos >= 0)
  {
    if (Pos == 0)
      StrBasic = StrTarget + StringSubstr(StrBasic, Pos + Len);
    else
      StrBasic = StringSubstr(StrBasic, 0, Pos) + StrTarget + StringSubstr(StrBasic, Pos + Len);

    Pos = StringFind(StrBasic, StrSource);
  }

  return;
}

int CreateHST( string Symb, int period )
{
  int Tmp[15];
  int handle = FileOpenHistory(Symb + period + ".hst", FILE_BIN|FILE_WRITE);

  FileWriteInteger(handle, 400);
  FileWriteString(handle, "Created by " + WindowExpertName(), 64);
  FileWriteString(handle, Symb, 12);
  FileWriteInteger(handle, period);
  FileWriteInteger(handle, 5); // Digits
  FileWriteArray(handle, Tmp, 0, 15);

  return(handle);
}

void SaveBar( int handle, double& DataBar[] )
{
  FileWriteInteger(handle, DataBar[0]);
  FileWriteArray(handle, DataBar, 1, AMOUNT_DATA - 1);

  return;
}

void GetTickerHistory( int hSession, string TickerName, int SourceNum )
{
  static double DataBar[AMOUNT_DATA];
  string URL, Strings[];
  int Amount, handle;
  int FirstBarTime = 0, LastBarTime = 0, AmountBars = 0;
  bool FlagFirst = TRUE;

  SourceNum %= AMOUNT_SOURCE;
  URL = URLS[SourceNum];

  ChangeString(TickerName, " ", "");
  ChangeString(URL, "[TICKERNAME]", TickerName);

  if (!HTTPToFile(hSession, URL, FileName, TickerName))
    return;

  Amount = FileToStrings(FileName, Strings);

  if (Amount <= 0)
  {
    Alert(WindowExpertName() + ": Ticker \"" + TickerName + "\" is not found on " + SourceName[SourceNum] + ".");

    return;
  }

  ChangeString(TickerName, ":", "_");
  TickerName = TickerName + "_" + PostFix[SourceNum];

  handle = CreateHST(TickerName, PERIOD_D1);

  for (int i = 0; i < Amount; i++)
  {
    Parsing(Strings[i], DataBar, SourceNum);

    if (DataBar[0] >= 0)
    {
      if (FlagFirst)
      {
        FirstBarTime = DataBar[0];
        AmountBars = -i;
        FlagFirst = FALSE;
      }

      SaveBar(handle, DataBar);
    }
  }

  FileClose(handle);

  if (!FlagFirst)
  {
    LastBarTime = DataBar[0];
    AmountBars += Amount;
  }

  Alert(WindowExpertName() + ": Symbol (offline) \"" + TickerName + "\" (" +
        TimeToStr(FirstBarTime, TIME_DATE) + " - " + TimeToStr(LastBarTime, TIME_DATE) +
        ", " + AmountBars + " bars) is created.");

  return;
}

int FileToStrings2( string FileName, string& Strings[] )
{
  int Amount = 0;
  int handle = FileOpen(FileName, FILE_CSV|FILE_READ);

  if (handle <= 0)
    return(Amount);

  ArrayResize(Strings, MAX_AMOUNT_TICKERS);

  while (!FileIsEnding(handle))
  {
    Strings[Amount] = FileReadString(handle);

    if (StringLen(Strings[Amount]) == 0)
      break;

    Amount++;
  }

  FileClose(handle);

  ArrayResize(Strings, Amount);

  return(Amount);
}

void start()
{
  string Tickers[];
  int Amount, hSession = InternetOpenA(AGENT, INTERNET_OPEN_TYPE_PRECONFIG, "", "", 0);

  if (hSession <= 0)
    return;

  Delimeters[0] = CharToStr(0x09);

  Amount = FileToStrings2(TickersList, Tickers);

  if (Amount > 0)
    for (int i = 0; i < Amount; i++)
      GetTickerHistory(hSession, Tickers[i], SourceNum);
  else if (StringLen(TickerName) > 0)
    GetTickerHistory(hSession, TickerName, SourceNum);

  InternetCloseHandle(hSession);

  Comment("");

  return;
}