#property show_inputs

#define MAX_AMOUNTSYMBOLS 10
#define MAX_POINTS 100000

extern string SymbolsStr = "AUDUSD, EURUSD, GBPUSD, USDCHF, USDJPY, USDCAD";
extern string BaseCurrency = "USD";
extern double PriceKoef = 10;
extern datetime StartTime = D'2010.01.01';

string Symbols[MAX_AMOUNTSYMBOLS];
int AmountSymbols;
int handle;

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

datetime GetStartTime( datetime StartTime )
{
  datetime Tmp;
  int Pos;
  
  for (int i = 0; i < AmountSymbols; i++)
  {
    Pos = iBarShift(Symbols[i], Period(), StartTime);
    Tmp = iTime(Symbols[i], Period(), Pos);
    
    if (Tmp > StartTime)
      StartTime = Tmp;
  }
  
  return(StartTime);
}

void CreateHandle()
{
  string FileName, SymbolName;
  int Tmp[15], TmpTime;

  SymbolName = "Roff_" + BaseCurrency;
  FileName = SymbolName + Period() + ".hst";
  handle = FileOpenHistory(FileName, FILE_BIN|FILE_WRITE);
  
  FileWriteInteger(handle, 400);
  FileWriteString(handle, "Created by " + WindowExpertName(), 64);
  FileWriteString(handle, SymbolName, 12);
  FileWriteInteger(handle, Period());
  FileWriteInteger(handle, Digits);
  FileWriteArray(handle, Tmp, 0, 15);

  return;
}

void init()
{
  AmountSymbols = StrToStringS(SymbolsStr, ",", Symbols);
  StartTime = GetStartTime(StartTime);
  CreateHandle();
    
  return;
}

void deinit()
{
  FileClose(handle);
  
  return;
}

double GetPrice( string Symb, int time )
{
  double Price;
  
  Price = iClose(Symb, Period(), iBarShift(Symb, Period(), time));

  if (StringSubstr(Symb, 0, 3) == BaseCurrency)
    Price = 1 / Price;
  
  return(Price);
}

int GetNextTime( int CurrTime )
{
  static int Pos[MAX_AMOUNTSYMBOLS];
  int i, MinTime, Tmp;
  
  for (i = 0; i < AmountSymbols; i++)
  {
    Pos[i] = iBarShift(Symbols[i], Period(), CurrTime) - 1;
    
    if (Pos[i] < 0)
      return(-1);
  }

  MinTime = iTime(Symbols[0], Period(), Pos[0]);
  
  for (i = 1; i < AmountSymbols; i++)
  {
    Tmp = iTime(Symbols[i], Period(), Pos[i]);
    
    if (Tmp < MinTime)
      MinTime = Tmp;
  }
      
  return(MinTime);
}

double CreatePrice( int time )
{
  double Price = 1;
  
  for (int i = 0; i < AmountSymbols; i++)
    Price *= GetPrice(Symbols[i], time);
      
  Price = PriceKoef * MathPow(Price, 1.0 / AmountSymbols);
      
  return(Price);
}

void WriteBar( int time, double OpenPrice, double ClosePrice )
{
  double HighPrice = MathMax(OpenPrice, ClosePrice);
  double LowPrice = MathMin(OpenPrice, ClosePrice);
  
  FileWriteInteger(handle, time);
  FileWriteDouble(handle, OpenPrice);
  FileWriteDouble(handle, LowPrice);
  FileWriteDouble(handle, HighPrice);
 
 
  FileWriteDouble(handle, ClosePrice);
  FileWriteDouble(handle, 2);
  
//  FileFlush(handle);
  
  return;
}

void start()
{
  int CurrTime = StartTime;
  double Price, PrevPrice;
  
  PrevPrice = CreatePrice(CurrTime);

  while (CurrTime > 0)
  {
    Price = CreatePrice(CurrTime);
    
    WriteBar(CurrTime, PrevPrice, Price);
    
    PrevPrice = Price;
    
    CurrTime = GetNextTime(CurrTime);
  }

  return; 
}