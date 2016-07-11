#include <FdkLevel2.mqh>

#define LEVEL2_MAXDEPTH 50

// if this variable not equal to zero then plugin stared
int gTrader = 0;

string SymbolSubscribe[];

int AmountBids, AmountAsks;
double Bids[], BidVols[];
double Asks[], AskVols[];

bool RealSymbol( string Symb )
{
  return(MarketInfo(Symb, MODE_TRADEALLOWED) == 1);
}

bool SubscribeSymbol( string Symb, int Level2Depth = LEVEL2_MAXDEPTH )
{
  bool Res = (gTrader != 0);

  if (Res)
    FdkSubscribe(gTrader, Symb, Level2Depth);

  return(Res);
}

bool UnsubscribeSymbol( string Symb )
{
  bool Res = (gTrader > 0);

  if (Res)
    FdkUnsubscribe(gTrader, Symb);

  return(Res);
}

void InitLevel2( string &Symbols[] )
{
  int isServerAllowed[1];
  int AmountSubscribe = 0;
  int Size = ArraySize(Symbols);

  ArrayResize(SymbolSubscribe, Size);

  gTrader = FdkCreate(isServerAllowed, AccountServer(), TerminalCompany(), AccountCompany());

  if (!isServerAllowed[0])
    Alert("Unsupported metatrader server");
  else
  {
    for (int i = 0; i < Size; i++)
      if (RealSymbol(Symbols[i]))
      {
        SubscribeSymbol(Symbols[i]);

        SymbolSubscribe[AmountSubscribe] = Symbols[i];

        AmountSubscribe++;
      }

    ArrayResize(SymbolSubscribe, AmountSubscribe);
  }

  return;
}

void DeinitLevel2()
{
  int AmountSubscribe = ArraySize(SymbolSubscribe);

  // close the plugin
  if(gTrader > 0)
  {
    for (int i = 0; i < AmountSubscribe; i++)
      UnsubscribeSymbol(SymbolSubscribe[i]);

    FdkDelete(gTrader);

    gTrader = 0;
  }

  return;
}

bool GetLevel2( string symbol, int l2Depth = LEVEL2_MAXDEPTH )
{
  static int SizeBids[1];
  static int SizeAsks[1];

  bool Res = (gTrader != 0);

  if (Res)
  {
    if ((l2Depth < 1) || (l2Depth > LEVEL2_MAXDEPTH))
      l2Depth = LEVEL2_MAXDEPTH;

    SizeBids[0] = l2Depth;
    SizeAsks[0] = l2Depth;

    ArrayResize(Bids, SizeBids[0]);
    ArrayResize(BidVols, SizeBids[0]);

    ArrayResize(Asks, SizeAsks[0]);
    ArrayResize(AskVols, SizeAsks[0]);

    FdkRefreshQuotes(gTrader);
    FdkGetQuotes(gTrader, symbol, SizeBids, Bids, BidVols, SizeAsks, Asks, AskVols);

    double lotSize = MarketInfo(symbol, MODE_LOTSIZE);

    if (lotSize != 0)
    {
      for (int i = 0; i < SizeBids[0]; i++)
        BidVols[i] = BidVols[i] / lotSize;

      for (i = 0; i < SizeAsks[0]; i++)
        AskVols[i] = AskVols[i] / lotSize;
    }

    AmountBids = SizeBids[0];
    AmountAsks = SizeAsks[0];
  }

  return(Res);
}