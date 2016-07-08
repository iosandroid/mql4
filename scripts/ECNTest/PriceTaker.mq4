#include <../Matching/NamedPipeServer.mqh>
#include <../Matching/Globals.mqh>

extern double BugLot = 5;

void init()
{
  SetSymbols();

  CreatePipeServer(ServerName);

  start();

  return;
}

void deinit()
{
  DestroyPipeServer();

  return;
}

double GetSymbolLot( string Symb )
{
  double Lots = 0;

  for (int i = OrdersTotal() - 1; i >= 0; i--)
    if (OrderSelect(i, SELECT_BY_POS))
      if ((OrderMagicNumber() == MAGIC) && (OrderSymbol() == Symb))
      {
        if (OrderType() == OP_BUY)
          Lots += OrderLots();
        else if (OrderType() == OP_SELL)
          Lots -= OrderLots();
      }

  return(Lots);
}

void OpenPosition( string Symb, int Type, double Lots, double OpenPrice)
{
  static string Types[] = {"BUY", "SELL"};

  if (MathAbs(GetSymbolLot(Symb)) < BugLot)
    MyOrderSend(Symb, Type, Lots, OpenPrice, 0);
  else
  {
    GetSymbolData(Symb);

    Alert("BUG: NettoLot = " + DoubleToStr(GetSymbolLot(Symb), LOTDIGITS) +
          " > " + DoubleToStr(BugLot, LOTDIGITS) +
          ", cannot open new position - " + Symb + " " + Types[Type] +
          " Lots" + DoubleToStr(Lots, LOTDIGITS) + " OpenPrice = " + DoubleToStr(OpenPrice, digits) +
          ", Bid = " + DoubleToStr(PriceBid, digits) + ", Ask = " + DoubleToStr(PriceAsk, digits));
  }

  return;
}

string PriceTaker()
{
  static int PrevTickCount = 0;
  static string PrevSymb = NULLSYMBOL;
  int Type, TickCount;
  double OpenPrice, Lots;
  string Symb, arrMessages[];
  int MessagesRetrieved = CheckForPipeMessages(arrMessages);

  for (int i = 0; i < MessagesRetrieved; i++)
  {
    GetMessageData(arrMessages[i], Symb, Type, OpenPrice, Lots, TickCount);

    GetSymbolData(Symb);

    if (TickCount > PrevTickCount) // WARNING: GetTickCount() may be is negative!
    {
      PrevSymb = Symb;

      if (((Type == OP_BUY) && EqualPrices(OpenPrice, PriceBid)) ||
          ((Type == OP_SELL) && EqualPrices(OpenPrice, PriceAsk)))
      {
        if (OrderScan(Symb, Type) != OP_EMPTY)
        {
          if (OrderLots() >= Lots)
            if (!OrderClose(OrderTicket(), Lots, OpenPrice, 0))
              OpenPosition(Symb, Types[Type], Lots, OpenPrice);
        }
        else
          OpenPosition(Symb, Types[Type], Lots, OpenPrice);

        PrevTickCount = GetTickCount();
      }
    }
  }

  return(PrevSymb);
}

void start()
{
  while(!IsStopped())
  {
    CloseAllWithoutSymbol(PriceTaker());

    Sleep(PAUSE);
  }

  return;
}

