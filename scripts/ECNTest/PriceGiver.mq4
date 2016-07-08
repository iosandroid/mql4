#include <../Matching/NamedPipeClient.mqh>
#include <../Matching/Globals.mqh>

extern double Lots = 1;
extern double CommissionProcent = 0.005;

void SendMessage( string Message )
{
  SendPipeMessage2(ServerName, Message);

  return;
}

bool Condition( string Symb, int MinPips = 2 )
{
  GetSymbolData(Symb);

  return(PriceAsk - PriceBid > CommissionProcent * PriceAsk / 100 + MinPips * point);
}

void ChangeTP()
{
  GetSymbolData(OrderSymbol());

  if (OrderType() == OP_BUY)
  {
    if ((!EqualPrices(OrderTakeProfit(), PriceAsk)) && (!EqualPrices(OrderOpenPrice(), PriceAsk))) // When BuyLimit accepting, PriceAsk == OpenPrice
      MyOrderModify(OrderOpenPrice(), PriceAsk - point);
  }
  else if (OrderType() == OP_SELL)
    if ((!EqualPrices(OrderTakeProfit(), PriceBid)) && (!EqualPrices(OrderOpenPrice(), PriceBid))) // When SellLimit accepting, PriceBid == OpenPrice
      MyOrderModify(OrderOpenPrice(), PriceBid + point);

  return;
}

void ChangeOrder()
{
  GetSymbolData(OrderSymbol());

  if (OrderType() == OP_BUYLIMIT)
  {
    if (EqualPrices(OrderOpenPrice(), PriceBid))
    {
      if (Condition(OrderSymbol(), 1))
        MyOrderModify(PriceBid, PriceAsk - point);
      else
        DeleteAllOrders();
    }
    else if (Condition(OrderSymbol()))
      MyOrderModify(PriceBid + point, PriceAsk - point);
    else
      DeleteAllOrders();
  }
  else if (OrderType() == OP_SELLLIMIT)
  {
    if (EqualPrices(OrderOpenPrice(), PriceAsk))
    {
      if (Condition(OrderSymbol(), 1))
        MyOrderModify(PriceAsk, PriceBid + point);
      else
        DeleteAllOrders();
    }
    else if (Condition(OrderSymbol()))
      MyOrderModify(PriceAsk - point, PriceBid + point);
    else
      DeleteAllOrders();
  }

  return;
}

bool SendLimit( string Symb, bool DirectionBUY )
{
  bool Res;

  GetSymbolData(Symb);

  if (DirectionBUY)
    Res = MyOrderSend(Symb, OP_BUYLIMIT, Lots, PriceBid + point, PriceAsk - point);
  else
    Res = MyOrderSend(Symb, OP_SELLLIMIT, Lots, PriceAsk - point, PriceBid + point);

  return(Res);
}

bool CheckOpenPosition()
{
  bool Res = (OrderScan(NULLSYMBOL, OP_BUY, OP_SELL) != OP_EMPTY);

  if (Res)
    ChangeTP();

  return(Res);
}

bool CheckLimitOrder()
{
  bool Res = (OrderScan(NULLSYMBOL, OP_BUYLIMIT, OP_SELLLIMIT) != OP_EMPTY);

  if (Res)
    ChangeOrder();

  return(Res);
}

void PriceGiver()
{
  static string PrevSymbol = NULLSYMBOL;
  static bool DirectionBUY = FALSE;
  int PrevPos, Pos, Type;

  if (CheckOpenPosition())
  {
    PrevSymbol = OrderSymbol();
    DirectionBUY = (OrderType() == OP_BUY);

    DeleteAllOrders();
  }
  else if (!CheckLimitOrder())
  {
    PrevPos = GetSymbolPos(PrevSymbol);

    Pos = NextSymbolPos(PrevPos);

    while (Pos != PrevPos)
    {
      if (Condition(Symbols[Pos]))
      {
        if (SendLimit(Symbols[Pos], !DirectionBUY))
          break;
        else
          PrevSymbol = Symbols[Pos];
      }

      Pos = NextSymbolPos(Pos);
    }
  }

  return;
}

void init()
{
  SetSymbols();

  start();

  return;
}

void deinit()
{
  DeleteAllOrders();
  CloseAllPositions();

  return;
}

void Send2PriceTaker()
{
  int Type = OrderScan(NULLSYMBOL, OP_BUY, OP_SELL);

  if (Type != OP_EMPTY)
    SendMessage(SetMessage(OrderSymbol(), OrderType(), OrderTakeProfit(), OrderLots()));
  else // PriceGiver sends to the PriceTaker only one fresh (actual) message (see DEFAULT_MAX_PIPES in NamedPipeServer.mqh).
  {
    Type = OrderScan(NULLSYMBOL, OP_BUYLIMIT, OP_SELLLIMIT);

    SendMessage(SetMessage(OrderSymbol(), OrderType(), OrderOpenPrice(), OrderLots()));
  }

  return;
}

void start()
{
  while(!IsStopped())
  {
    PriceGiver();

    Send2PriceTaker();

    Sleep(PAUSE);
  }

  return;
}