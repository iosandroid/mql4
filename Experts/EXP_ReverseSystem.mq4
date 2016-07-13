#define HEADER 148
#define BARSIZE 60  //

extern int Pips = 50;
extern double Lots = 0.1;

int handle;
bool MainError;

long GetTime( int Pos )
{
  long PosTime;
  
  FileSeek(handle, HEADER + Pos, SEEK_SET);
  PosTime = FileReadLong(handle);

  //Print("PosTime: " + PosTime + " Open: " + FileReadDouble(handle) + " High: " + FileReadDouble(handle) + " Low: " + FileReadDouble(handle) + " Close: " + FileReadDouble(handle));
  return(PosTime);
}

bool FindTimePlace( int SearchTime )
{
  long LeftTime, RightTime, PosTime;
  long Left, Right, Pos;
  
  Left = 0;
  Right = FileSize(handle) - HEADER - BARSIZE;

  LeftTime = GetTime(Left);
  RightTime = GetTime(Right);
  
  while ((LeftTime < SearchTime) && (SearchTime < RightTime))
  {
    Pos = (Left + Right) / 2;
    Pos -= Pos % BARSIZE;
    
    if (Pos == Left)
      break;
    
    PosTime = GetTime(Pos);    
    
    if (SearchTime >= PosTime)
    {
      Left = Pos;
      LeftTime = GetTime(Left);
    }
    else // if (SearchTime < PosTime)
    {
      Right = Pos;
      RightTime = GetTime(Right);
    }
  }  
  
  if (SearchTime <= RightTime)
  {
    FileSeek(handle, Left + HEADER, SEEK_SET);
    return(TRUE);
  }
  else
    return(FALSE);
}

void init()
{
  string filename = Symbol() + Period() + ".hst";
  handle = FileOpen(filename, FILE_BIN|FILE_READ);
  
  Print(filename);
  
  if (handle > 0)
  {
    Print("File: " + filename + " opened successfully.");
    MainError = TRUE;
  }
  else
  {    
    Print("File: " + filename + " could not be opened: err: " + GetLastError());
    MainError = FALSE;
        
    return;
  }

  MainError = FindTimePlace(Time[0]);
  
  if (!MainError)
  {
    Print("FindTimePlace: error");
    FileClose(handle);
  }
    
  return;
}

void deinit()
{
  if (MainError)
    FileClose(handle);
  
  return;
}

bool GetPrices( long& PriceTime, double& PriceLow, double& PriceHigh)
{
  double PriceOpen;
  double PriceClose;
  long   PriceVolume;
  int    PriceSpread;
  long   PriceRealVolume;

  PriceTime       = FileReadLong(handle); //read time  
  PriceOpen       = FileReadDouble(handle);
  PriceHigh       = FileReadDouble(handle) / Point + 0.1; // read high value
  PriceLow        = FileReadDouble(handle) / Point + 0.1; // read low value  
  PriceClose      = FileReadDouble(handle);
  PriceVolume     = FileReadLong(handle);
  PriceSpread     = FileReadInteger(handle);
  PriceRealVolume = FileReadLong(handle);
  
  //Print("PriceTime: " + PriceTime + " PriceHigh: " + PriceHigh + " PriceLow: " + PriceLow);
  
  if (FileTell(handle) + BARSIZE <= FileSize(handle))
  {  
    return(TRUE);
  }
  else
  {    
    return(FALSE);
  }
}

long GetTimeTrade()
{
  static bool FlagUP = TRUE;
  static double Min = 999999;
  static double Max = 0;
  static long NTime;
  long ResTime;
  
  long PriceTime;
  double PriceLow, PriceHigh;
    
  while (TRUE)  
  {
    if (!GetPrices(PriceTime, PriceLow, PriceHigh))
    {
      Print("Get prices failed.");
      return(-1);
    }    

    if (FlagUP)
    {
      if (PriceHigh > Max)
      {
        Max = PriceHigh;
        NTime = PriceTime;
      }
      else if (Max - PriceLow >= Pips)
      {
        FlagUP = FALSE;
        Min = PriceLow;
        
        break;
      }
    }
    else // (FlagUP == FALSE)
    {
      if (PriceLow < Min)
      {
        Min = PriceLow;
        NTime = PriceTime;
      }
      else if (PriceHigh - Min >= Pips)
      {
        FlagUP = TRUE;
        Max = PriceHigh;
        
        break;
      }
    }
  }
  
  ResTime = NTime;
  NTime = PriceTime;

  return(ResTime);
}

void CloseOrder( int Ticket )
{
  OrderSelect(Ticket, SELECT_BY_TICKET);
  
  if (OrderType() == OP_BUY)
    OrderClose(Ticket, OrderLots(), Bid, 0);
  else  // (OrderType() == OP_SELL)
    OrderClose(Ticket, OrderLots(), Ask, 0);

  return;  
}

int ReverseOrder( int Ticket)
{
  if (Ticket == 0)
    Ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, 0, 0, 0);
  else
  {
    OrderSelect(Ticket, SELECT_BY_TICKET);
  
    if (OrderType() == OP_BUY)
    {
      OrderClose(Ticket, OrderLots(), Bid, 0);
      Ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, 0, 0, 0);
    }
    else  // (OrderType() == OP_SELL)
    {
      OrderClose(Ticket, OrderLots(), Ask, 0);
      Ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, 0, 0, 0);
    }
  }
  
  return(Ticket);
}

void System()
{
  static int  Ticket = 0;
  static long NewTime = 0;
  
  if (NewTime < 0)
  {
    return;
  }
    
  if (Time[0] < NewTime)
  {
    return;
  }

  Ticket = ReverseOrder(Ticket);
  
  NewTime = GetTimeTrade();
  Print("NextTime: " + NewTime);
  
  if (NewTime < 0)
    CloseOrder(Ticket);
}

void start()
{
  if (!MainError)
  {
    Print("!MainError");
    return;
  }

  System();
    
  return;
}