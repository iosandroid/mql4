#define MAINSEEK 148
#define BARSIZE 44  // LONG_VALUE + 5 * DOUBLE_VALUE

extern int Pips = 50;
extern double Lots = 0.1;

int handle;
bool MainError;

int GetTime( int Pos )
{
  int PosTime;
  
  FileSeek(handle, MAINSEEK + Pos, SEEK_SET);
  PosTime = FileReadInteger(handle);

  return(PosTime);
}

bool FindTimePlace( int SearchTime )
{
  int LeftTime, RightTime, PosTime;
  int Left, Right, Pos;
  
  Left = 0;
  Right = FileSize(handle) - MAINSEEK - BARSIZE;
  
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
    FileSeek(handle, Left + MAINSEEK, SEEK_SET);
    return(TRUE);
  }
  else
    return(FALSE);
}

void init()
{
  handle = FileOpenHistory(Symbol() + Period() + ".hst", FILE_BIN|FILE_READ);
  
  if (handle > 0)
    MainError = TRUE;
  else
  {
    MainError = FALSE;
    
    return;
  }

  MainError = FindTimePlace(Time[0]);
  
  if (!MainError)
    FileClose(handle);
    
  return;
}

void deinit()
{
  if (MainError)
    FileClose(handle);
  
  return;
}

bool GetPrices( int& PriceTime, int& PriceLow, int& PriceHigh)
{
  PriceTime = FileReadInteger(handle);
  FileSeek(handle, DOUBLE_VALUE, SEEK_CUR);
  PriceLow = FileReadDouble(handle) / Point + 0.1;
  PriceHigh = FileReadDouble(handle) / Point + 0.1;
  FileSeek(handle, 2 * DOUBLE_VALUE, SEEK_CUR);

  if (FileTell(handle) + BARSIZE <= FileSize(handle))
    return(TRUE);
  else
    return(FALSE);
}

int GetTimeTrade()
{
  static bool FlagUP = TRUE;
  static int Min = 999999;
  static int Max = 0;
  static int NTime;
  int ResTime;
  
  int PriceTime, PriceLow, PriceHigh;
    
  while (TRUE)
  {
    if (!GetPrices(PriceTime, PriceLow, PriceHigh))
      return(-1);

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
  static int Ticket = 0;
  static int NewTime = 0;
  
  if (NewTime < 0)
    return;
    
  if (Time[0] < NewTime)
    return;

  Ticket = ReverseOrder(Ticket);
  
  NewTime = GetTimeTrade();
  
  if (NewTime < 0)
    CloseOrder(Ticket);
}

void start()
{
  if (!MainError)
    return;

  System();
    
  return;
}