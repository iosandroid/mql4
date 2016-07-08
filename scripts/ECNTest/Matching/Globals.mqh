#define PAUSE 10
#define MAXERRORS 9

#define MAGIC 12345
#define LOTDIGITS 2

#define DELIMETER " "
#define NULLSYMBOL ""

#define OP_EMPTY -1

#define STOPLOSS 1000

extern string ServerName = "PriceTaker";

double PriceBid, PriceAsk, point;
int digits;

string Symbols[];
int AmountSymbols;

int Types[] = {OP_SELL, OP_BUY, OP_BUY, OP_SELL};

int GetSymbolPos( string Symb )
{
  int Pos;

  for (Pos = 0; Pos < AmountSymbols; Pos++)
    if (Symbols[Pos] == Symb)
      break;

  if (Pos >= AmountSymbols)
    Pos = 0;

  return(Pos);
}

int NextSymbolPos( int Pos)
{
  if (Pos >= AmountSymbols - 1)
    Pos = 0;
  else
    Pos++;

  return(Pos);
}

int SymbolsList( string &Symbols[] )
{
   int Offset, SymbolsNumber;

   int hFile = FileOpenHistory("symbols.sel", FILE_BIN|FILE_READ);
   SymbolsNumber = (FileSize(hFile) - 4) / 128;
   Offset = 116;

   ArrayResize(Symbols, SymbolsNumber);

   FileSeek(hFile, 4, SEEK_SET);

   for(int i = 0; i < SymbolsNumber; i++)
   {
      Symbols[i] = FileReadString(hFile, 12);
      FileSeek(hFile, Offset, SEEK_CUR);
   }

   FileClose(hFile);

   return(SymbolsNumber);
}

bool RealSymbol( string Symb )
{
  return(MarketInfo(Symb, MODE_TRADEALLOWED) == 1);
}

void SetSymbols()
{
  int Count = 0;
  AmountSymbols = SymbolsList(Symbols);

  for (int i = 0; i < AmountSymbols; i++)
    if (RealSymbol(Symbols[i]))
    {
      Symbols[Count] = Symbols[i];

      Count++;
    }

  AmountSymbols = Count;

  ArrayResize(Symbols, AmountSymbols);

  return;
}

bool EqualPrices( double Price1, double Price2, double Tmp = 0 )
{
  return(MathAbs(Price1 - Price2) < Tmp + point / 2);
}

#define MAX_TYPES 2

int OrderScan( string Symb, int Type1, int Type2 = OP_EMPTY )
{
  int Types[MAX_TYPES];

  Types[0] = Type1;
  Types[1] = Type2;

  for (int i = 0; i < MAX_TYPES; i++)
  {
    if (Types[i] == OP_EMPTY)
      break;

    for (int j = OrdersTotal() - 1; j >= 0; j--)
    {
      if (OrderSelect(j, SELECT_BY_POS))
        if ((OrderType() == Types[i]) && (OrderMagicNumber() == MAGIC))
          if ((Symb == NULLSYMBOL) || (OrderSymbol() == Symb))
            return(Types[i]);
    }
  }

  return(OP_EMPTY);
}

void GetSymbolData( string Symb )
{
  RefreshRates();

  PriceBid = MarketInfo(Symb, MODE_BID);
  PriceAsk = MarketInfo(Symb, MODE_ASK);
  point = MarketInfo(Symb, MODE_POINT);
  digits = MarketInfo(Symb, MODE_DIGITS);

  return;
}

bool CloseAllPositions( string Symb = NULLSYMBOL )
{
  bool Res = TRUE;
  int Type = OrderScan(Symb, OP_SELL, OP_BUY);

  while ((Type != OP_EMPTY) && Res)
  {
    GetSymbolData(OrderSymbol());

    if (Type == OP_BUY)
      Res = OrderClose(OrderTicket(), OrderLots(), PriceBid, 0);
    else // (Type == OP_SELL)
      Res = OrderClose(OrderTicket(), OrderLots(), PriceAsk, 0);

    Type = OrderScan(Symb, OP_SELL, OP_BUY);
  }

  return(Res);
}

bool DeleteAllOrders()
{
  bool Res = TRUE;
  int Type = OrderScan(NULLSYMBOL, OP_SELLLIMIT, OP_BUYLIMIT);

  while ((Type != OP_EMPTY) && Res)
  {
    Res = OrderDelete(OrderTicket());

    Type = OrderScan(NULLSYMBOL, OP_SELLLIMIT, OP_BUYLIMIT);
  }

  return(Res);
}

bool CloseBy( string Symb )
{
  int SellTicket, OrderTime;
  bool Res = TRUE;
  int Type = OrderScan(Symb, OP_SELL);

  while ((Type != OP_EMPTY) && Res)
  {
    SellTicket = OrderTicket();
    OrderTime = OrderOpenTime();

    Res = (OrderScan(Symb, OP_BUY) != OP_EMPTY);

    if (Res)
    {
      if (OrderOpenTime() < OrderTime)
        Res = OrderCloseBy(OrderTicket(), SellTicket);
      else
        Res = OrderCloseBy(SellTicket, OrderTicket());
    }

    Type = OrderScan(Symb, OP_SELL);
  }

  return(Res);
}

void CloseAllWithoutSymbol( string Symb )
{
  for (int i = 0; i < AmountSymbols; i++)
  {
    CloseBy(Symbols[i]);

    if ((Symbols[i] != Symb))
      CloseAllPositions(Symbols[i]);
  }

  return;
}

bool MyOrderSend( string Symb, int Type, double Lots, double OpenPrice, double TPPrice )
{
  double SLPrice = 0;

  if (Type == OP_BUYLIMIT)
    SLPrice = TPPrice - STOPLOSS * point;
  else if (Type == OP_SELLLIMIT)
    SLPrice = TPPrice + STOPLOSS * point;

  GetSymbolData(Symb);

  SLPrice = NormalizeDouble(SLPrice, digits);
  TPPrice = NormalizeDouble(TPPrice, digits);
  OpenPrice = NormalizeDouble(OpenPrice, digits);

  return(OrderSend(Symb, Type, Lots, OpenPrice, 0, SLPrice, TPPrice, "", MAGIC) > 0);
}

bool _OrderModify( int ticket, double price, double stoploss, double takeprofit, datetime expiration, color arrow_color=CLR_NONE )
{
  bool Res = OrderModify(ticket, price, stoploss, takeprofit, expiration, arrow_color);

  if (!Res)
  {
    RefreshRates();

    Res = OrderSelect(ticket, SELECT_BY_TICKET);

    if (Res)
      Res = EqualPrices(OrderOpenPrice(), price) && EqualPrices(OrderStopLoss(), stoploss) && EqualPrices(OrderTakeProfit(), takeprofit);
  }

  return(Res);
}

string OrderToStr()
{
  static string Types[] = {"Buy", "Sell", "BuyLimit", "SellLimit", "BuyStop", "SellStop"};

  GetSymbolData(OrderSymbol());

  return(OrderTicket() + " " + Types[OrderType()] + " " + DoubleToStr(OrderLots(), LOTDIGITS) + ": Open = " + DoubleToStr(OrderOpenPrice(), digits) +
         ",  TP = " + DoubleToStr(OrderTakeProfit(), digits) + " (Bid = " + DoubleToStr(PriceBid, digits) +  ",  Ask = " + DoubleToStr(PriceAsk, digits) + ")");
}
void MyOrderModify( double OpenPrice, double TPPrice, int MaxErrors = MAXERRORS )
{
  static int ErrorCount = 0;
  static int PrevTicket = 0;
  double SLPrice = OrderStopLoss();

  if (OrderType() == OP_BUYLIMIT)
    SLPrice = TPPrice - STOPLOSS * point;
  else if (OrderType() == OP_SELLLIMIT)
    SLPrice = TPPrice + STOPLOSS * point;

  if (PrevTicket != OrderTicket())
  {
    PrevTicket = OrderTicket();

    ErrorCount = 0;
  }

  GetSymbolData(OrderSymbol());

  SLPrice = NormalizeDouble(SLPrice, digits);
  TPPrice = NormalizeDouble(TPPrice, digits);
  OpenPrice = NormalizeDouble(OpenPrice, digits);

  if ((!EqualPrices(OrderTakeProfit(), TPPrice)) || (!EqualPrices(OrderOpenPrice(), OpenPrice)))
  {
    if (_OrderModify(OrderTicket(), OpenPrice, SLPrice, TPPrice, 0))
      ErrorCount = 0;
    else
    {
      ErrorCount++;

      if (ErrorCount > MaxErrors)
      {
        Alert("BUG (broker/terminal) " + OrderToStr() + " -> Open = " + DoubleToStr(OpenPrice, digits), ", TP = " + DoubleToStr(TPPrice, digits));

        CloseAllPositions();
        DeleteAllOrders();

        ErrorCount = 0;
      }
    }
  }

  return;
}

string SetMessage( string Symb, int Type, double OpenPrice, double Lots )
{
  GetSymbolData(Symb);

  return(Symb + DELIMETER + Types[Type] + DELIMETER + DoubleToStr(OpenPrice, digits) +
                DELIMETER + DoubleToStr(Lots, LOTDIGITS) + DELIMETER + GetTickCount());
}

string GetStr( string &Str, string Delimeter )
{
  int Pos = StringFind(Str, Delimeter);
  string StrRes = StringSubstr(Str, 0, Pos);

  Str = StringSubstr(Str, Pos + 1);

  return(StrRes);
}

void GetMessageData( string Message, string &Symb, int &Type, double &OpenPrice, double &Lots, int &TickCount )
{
  Symb = GetStr(Message, DELIMETER);
  Type = StrToInteger(GetStr(Message, DELIMETER));

  OpenPrice = StrToDouble(GetStr(Message, DELIMETER));
  Lots = StrToDouble(GetStr(Message, DELIMETER));

  TickCount = StrToInteger(GetStr(Message, DELIMETER));

  return;
}

