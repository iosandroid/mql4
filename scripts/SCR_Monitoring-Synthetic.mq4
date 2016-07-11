#property show_inputs

#import "user32.dll"
  int PostMessageA(int hWnd,int Msg,int wParam,int lParam);
#import

#define WM_COMMAND 0x0111

#define PAUSE 100

extern string Currency = "USD";

string Symbol1, Symbol2;
bool Math; // 0 - S1 / S2, 1 - S1 * S2, 2 - 1 / (S1 * S2)

int handle;
string SymbolName;

int time;
double open, low, high, close;
int volume;
double PriceBid, PriceAsk;
double Bid1 = 0, Bid2 = 0, Ask1 = 0, Ask2 = 0;
int Digits1, Digits2;  

double MinSpread, MaxSpread, AverageSpread;

bool RealSymbol( string Str )
{
  return(MarketInfo(Str, MODE_BID) != 0);
}

void GetSymbols()
{
  string Currency1, Currency2;
  string SymbolPrefix;
  string Str1, Str2;
  
  Currency1 = StringSubstr(Symbol(), 0, 3);
  Currency2 = StringSubstr(Symbol(), 3, 3);
  SymbolPrefix = StringSubstr(Symbol(), 6, StringLen(Symbol()) - 6);
  
  Str1 = Currency1 + Currency + SymbolPrefix;
  Str2 = Currency + Currency1 + SymbolPrefix;
  
  if (RealSymbol(Str1))
  {
    Symbol1 = Str1; 
    
    Str1 = Currency2 + Currency + SymbolPrefix;
    Str2 = Currency + Currency2 + SymbolPrefix;
    
    if (RealSymbol(Str1))
    {
      Symbol2 = Str1; 
      Math = 0; //  S1 / S2
    }
    else if (RealSymbol(Str2))
    {
      Symbol2 = Str2; 
      Math = 1; // S1 * S2
    }
  }
  else if (RealSymbol(Str2))
  {
    Symbol2 = Str2; 
    
    Str1 = Currency2 + Currency + SymbolPrefix;
    Str2 = Currency + Currency2 + SymbolPrefix;
    
    if (RealSymbol(Str1))
    {
      Symbol1 = Str1; 
      Math = 2; // 1 / (S1 * S2)
    }
    else if (RealSymbol(Str2))
    {
      Symbol1 = Str2; 
      Math = 0; // S1 / S2
    }
  }
  
  return;
}

bool GetPrices()
{  
  switch (Math)
  {
  case 0: // S1 / S2
    PriceBid = Bid1 / Ask2;
    PriceAsk = Ask1 / Bid2;
    break;
  case 1: // S1 * S2
    PriceBid = Bid1 * Bid2;
    PriceAsk = Ask1 * Ask2;
    break;
  case 2: // 1 / (S1 * S2)
    PriceBid = 1 / (Ask1 * Ask2);
    PriceAsk = 1 / (Bid1 * Bid2);
    break;
  }
  
  return;
}

bool SymbolChange()
{
  double NewBid1, NewBid2, NewAsk1, NewAsk2;

  NewBid1 = MarketInfo(Symbol1, MODE_BID);
  NewBid2 = MarketInfo(Symbol2, MODE_BID);
  NewAsk1 = MarketInfo(Symbol1, MODE_ASK);
  NewAsk2 = MarketInfo(Symbol2, MODE_ASK);
  
  if ((NormalizeDouble(NewBid1 - Bid1, Digits1) != 0) || (NormalizeDouble(NewBid2 - Bid2, Digits2) != 0) ||
      (NormalizeDouble(NewAsk1 - Ask1, Digits1) != 0) || (NormalizeDouble(NewAsk2 - Ask2, Digits2) != 0))
  {
    Bid1 = NewBid1;
    Bid2 = NewBid2;
    Ask1 = NewAsk1;
    Ask2 = NewAsk2;
    
    GetPrices();
    
    return(TRUE);
  }
  
  return(FALSE);
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
  int Tmp1, Tmp2;
  
  Tmp1 = iTime(Symbol1, Period(), 0);
  Tmp2 = iTime(Symbol2, Period(), 0);
  
  if (Tmp1 > Tmp2)
    return(Tmp1);
    
  return(Tmp2);
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

  SymbolName = StringSubstr(Symbol(), 0, 6) + "_" + Currency;
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
  int Spread = (Ask - Bid) / Point + 0.1;
  double SpreadX = (PriceAsk - PriceBid) / Point;
  string Str;
  
  Str = Symbol() + " spread = " + Spread + "\n" + SymbolName + " spread = " + DoubleToStr(SpreadX, 1);
  Str = Str + "\nDifference = " + DoubleToStr(Spread - SpreadX, 1);
  
  return(Str);
}

void init()
{  
  GetSymbols();
  
  Digits1 = MarketInfo(Symbol1, MODE_DIGITS);
  Digits2 = MarketInfo(Symbol2, MODE_DIGITS);

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