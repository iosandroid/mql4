#property show_inputs

#import "user32.dll"
  int PostMessageA(int hWnd,int Msg,int wParam,int lParam);
#import

#define WM_COMMAND 0x0111

#define PAUSE 100

#define MAX_AMOUNTSYMBOLS 10

extern string SymbolsStr = "AUDUSD, EURUSD, GBPUSD, USDCHF, USDJPY, USDCAD";
extern string BaseCurrency = "USD";
extern double PriceKoef = 10;

int time;
double open, low, high, close;
int volume;
double PriceBid, PriceAsk;
double Bids[MAX_AMOUNTSYMBOLS], Asks[MAX_AMOUNTSYMBOLS];

double MinSpread, MaxSpread, AverageSpread;

string SymbolName;
int handle;

string Symbols[MAX_AMOUNTSYMBOLS];
int AmountSymbols;

string StrDelSpaces( string Str )
{
  int Pos, Length;

  Str = StringTrimLeft(Str);
  Str = StringTrimRight(Str);

  Length = StringLen(Str) - 1;
  Pos = 1;

  while (Pos < Length)
    if (StringGetChar(Str, Pos) == ' ')
    {  
      Str = StringSubstr(Str, 0, Pos) + StringSubstr(Str, Pos + 1, 0);
      Length--;
    }
    else 
      Pos++;

  return(Str);
}

int StrToStringS( string Str, string Razdelitel, string &Output[] )
{
  int Pos, LengthSh;
  int Count = 0;

  Str = StrDelSpaces(Str);
  Razdelitel = StrDelSpaces(Razdelitel);

  LengthSh = StringLen(Razdelitel);

  while (TRUE)
  {
    Pos = StringFind(Str, Razdelitel);
    Output[Count] = StringSubstr(Str, 0, Pos);
    Count++;
 
    if (Pos == -1)
      break;
 
    Pos += LengthSh;
    Str = StringSubstr(Str, Pos);
  }

  return(Count);
}

void GetPrices()
{
  PriceBid = 1;
  PriceAsk = 1;
  
  for (int i = 0; i < AmountSymbols; i++)
    if (StringSubstr(Symbols[i], 0, 3) == BaseCurrency)
    {
      PriceBid /= Asks[i];
      PriceAsk /= Bids[i];
    }
    else
    {
      PriceBid *= Bids[i];
      PriceAsk *= Asks[i];
    }
    
  PriceBid = PriceKoef * MathPow(PriceBid, 1.0 / AmountSymbols);
  PriceAsk = PriceKoef * MathPow(PriceAsk, 1.0 / AmountSymbols);
  
  return;
}

bool SymbolChange()
{
  double NewBid, NewAsk;
  bool Res = FALSE;
  
  for (int i = 0; i < AmountSymbols; i++)
  {
    NewBid = MarketInfo(Symbols[i], MODE_BID);
    NewAsk = MarketInfo(Symbols[i], MODE_ASK);
    
    if ((NewBid != Bids[i]) || (NewAsk != Asks[i]))
    {
      Res = TRUE;
      
      Bids[i] = NewBid;
      Asks[i] = NewAsk;
    }
  }
    
  if (Res)
    GetPrices();
    
  return(Res);
}

void WriteBar()
{
  FileWriteInteger(handle, time);
  FileWriteDouble(handle, open);
  FileWriteDouble(handle, low);
  FileWriteDouble(handle, high);
  FileWriteDouble(handle, close);
  FileWriteDouble(handle, volume);
  
  FileFlush(handle);
  
  return;
}

int GetLastTime()
{
  int Tmp, MaxTime = 0;
  
  for (int i = 0; i < AmountSymbols; i++)
  {
    Tmp = iTime(Symbols[i], Period(), 0);
    
    if (Tmp > MaxTime)
      MaxTime = Tmp;
  }
  
  return(MaxTime);
}

void CreateNewBar()
{
  time = GetLastTime();
  
  open = PriceBid;
  low = PriceBid;
  high = PriceBid;
  close = PriceBid;
  
  volume = 1;
 
  return;
}

void ModifyBar()
{
  if (PriceBid > high)
    high = PriceBid;
  else if (PriceBid < low)
    low = PriceBid;
    
  close = PriceBid;

  volume++;
}

void CreateNewSpread()
{
  MinSpread = (PriceAsk - PriceBid) / Point;
  MaxSpread = MinSpread;
  AverageSpread = MinSpread;
  
  return;
}

void ModifySpread()
{
  double Spread = (PriceAsk - PriceBid) / Point;
  
  if (Spread > MaxSpread)
    MaxSpread = Spread;
  else if (Spread < MinSpread)
    MinSpread = Spread;
    
  AverageSpread += Spread;
  
  return;
}

void WriteSpread()
{
  int hSpread = FileOpen(SymbolName + Period() + "_Spread.dat", FILE_BIN|FILE_READ|FILE_WRITE);
  
  AverageSpread /= volume;
  
  FileSeek(hSpread, 0, SEEK_END);
  FileWriteInteger(hSpread, time);
  FileWriteDouble(hSpread, MaxSpread);
  FileWriteDouble(hSpread, AverageSpread);
  FileWriteDouble(hSpread, MinSpread);
  
  FileClose(hSpread);

  return;  
}

void CreateHandle()
{
  string FileName;
  int Tmp[15], TmpTime;

  SymbolName = "R_" + BaseCurrency;
  FileName = SymbolName + Period() + ".hst";
  handle = FileOpenHistory(FileName, FILE_BIN|FILE_READ|FILE_WRITE);
    
  if (FileSize(handle) > 0)
  {
    if (FileSize(handle) > 148)
    {
      FileSeek(handle, -44, SEEK_END);
      TmpTime = FileReadInteger(handle);
      
      if (TmpTime == time)
      {
        open = FileReadDouble(handle);
        low = FileReadDouble(handle);
        high = FileReadDouble(handle);
        close = FileReadDouble(handle);
        volume = FileReadDouble(handle);
      
        return;
      }
    }

    FileSeek(handle, 0, SEEK_END);
        
    return;
  }

  FileClose(handle);
  
  handle = FileOpenHistory(FileName, FILE_BIN|FILE_WRITE);
  
  FileWriteInteger(handle, 400);
  FileWriteString(handle, "Created by " + WindowExpertName(), 64);
  FileWriteString(handle, SymbolName, 12);
  FileWriteInteger(handle, Period());
  FileWriteInteger(handle, Digits);
  FileWriteArray(handle, Tmp, 0, 15);

  return;
}

void RefreshChart()
{
  int hwnd = WindowHandle(SymbolName, Period());

  PostMessageA(hwnd, WM_COMMAND, 33324, 0);
    
  return;
}

string GetComment()
{
  int SpreadX = (PriceAsk - PriceBid) / Point + 0.1;
  string Str;
  
  Str = SymbolsStr + "\n" + SymbolName + " spread = " + SpreadX;
  Str = Str + "\nPriceAsk = " + DoubleToStr(PriceAsk, Digits) +
              "\nPriceBid = " + DoubleToStr(PriceBid, Digits);
  
  return(Str);
}

void init()
{  
  AmountSymbols = StrToStringS(SymbolsStr, ",", Symbols);

  SymbolChange();
  CreateNewBar();
  CreateNewSpread();

  CreateHandle();
  
  return;
}

void deinit()
{
  FileClose(handle);
  
  Comment("");
  
  return;
}

void start()
{
  while (!IsStopped())
  {
    if (SymbolChange())
    {
      Comment(GetComment());
      
      if (time < GetLastTime())
      {
        WriteBar();
        WriteSpread();
        
        CreateNewBar();
        CreateNewSpread();

        RefreshChart();        
      }
      else
      {
        ModifyBar();
        ModifySpread();
      }
    }
    
    Sleep(PAUSE);
    RefreshRates();
  }
  
  return;
}