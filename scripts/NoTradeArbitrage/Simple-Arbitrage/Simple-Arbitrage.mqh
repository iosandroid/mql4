#include <../Simple-Arbitrage/Level2.mqh>

#define MAXSYMBOLS 4

#define EMPTY_CURRENCY ""
#define DIRECTION 1

int SymbolAmountBids[MAXSYMBOLS], SymbolAmountAsks[MAXSYMBOLS];
double SymbolBids[MAXSYMBOLS][LEVEL2_MAXDEPTH], SymbolBidVols[MAXSYMBOLS][LEVEL2_MAXDEPTH];
double SymbolAsks[MAXSYMBOLS][LEVEL2_MAXDEPTH], SymbolAskVols[MAXSYMBOLS][LEVEL2_MAXDEPTH];

int GetPosCurrency( string &Currencies[], string Currency )
{
  int Pos = 0;

  while (Currencies[Pos] != Currency)
  {
    if (Currencies[Pos] == EMPTY_CURRENCY)
    {
      Currencies[Pos] = Currency;

      break;
    }

    Pos++;
  }

  return(Pos);
}

int SetVector( int &Vector[], int Pos1, int Pos2 )
{
  int Res = DIRECTION;

  if ((Vector[Pos1] > 0) || (Vector[Pos2] < 0))
    Res = -DIRECTION;

  Vector[Pos1] += Res;
  Vector[Pos2] -= Res;

  return(Res);
}

bool CheckArbitrage( string &Symbols[], int &ArbitrageVector[], int AmountSymbols )
{
  string Currencies[];
  int i, Pos1, Pos2, Vector[];
  int Size = AmountSymbols << 1;
  bool Res = TRUE;

  ArrayResize(Currencies, Size);
  ArrayResize(Vector, Size);

  for (i = 0; i < Size; i++)
  {
    Currencies[i] = EMPTY_CURRENCY;

    Vector[i] = 0;
  }

  for (i = 0; i < AmountSymbols; i++)
  {
    Pos1 = GetPosCurrency(Currencies, StringSubstr(Symbols[i], 0, 3));
    Pos2 = GetPosCurrency(Currencies, StringSubstr(Symbols[i], 3, 3));

    ArbitrageVector[i] = SetVector(Vector, Pos1, Pos2);
  }

  for (i = 0; i < AmountSymbols; i++)
    if (Vector[i] != 0)
    {
      Res = FALSE;

      break;
    }

  return(Res);
}

bool GetLevels2( string &Symbols[], int AmountSymbols, int l2Depth = LEVEL2_MAXDEPTH )
{
  bool Res;
  int j;
  double Lot;

  for (int i = 0; i < AmountSymbols; i++)
  {
    Res = GetLevel2(Symbols[i], l2Depth);

    if (!Res)
      break;

    for (j = 0; j < AmountBids; j++)
    {
      SymbolBids[i][j] = Bids[j];
      SymbolBidVols[i][j] = BidVols[j];
    }

    for (j = 0; j < AmountAsks; j++)
    {
      SymbolAsks[i][j] = Asks[j];
      SymbolAskVols[i][j] = AskVols[j];
    }

    SymbolAmountBids[i] = AmountBids;
    SymbolAmountAsks[i] = AmountAsks;
  }

  return(Res);
}

double GetTickValue2( string Symb )
{
  return(AccountLeverage() * MarketInfo(Symb, MODE_TICKSIZE) * MarketInfo(Symb, MODE_MARGINREQUIRED) / MarketInfo(Symb, MODE_ASK));
}

double TrueTickValue( string Symb )
{
  double TickValue = MarketInfo(Symb, MODE_TICKVALUE);
  double Tmp = MarketInfo(Symb, MODE_MARGININIT);

  if (TickValue == 0)
    TickValue = GetTickValue2(Symb);

  if ((MarketInfo(Symb, MODE_MARGINCALCMODE) > 0) && (Tmp > 0))
    TickValue *=  MarketInfo(Symb, MODE_MARGINREQUIRED) / Tmp;

  return(TickValue);
}

double GetLot( string Symb, double Vector = 1 )
{
  RefreshRates();

  return(Vector * MarketInfo(Symb, MODE_TICKSIZE) / (MarketInfo(Symb, MODE_ASK) * TrueTickValue(Symb)));
}

double GetVolumes( string &Symbols[], int &ArbitrageVector[], int AmountSymbols, double Commission, double &NewVolumes[] )
{
  static int PosBid[MAXSYMBOLS], PosAsk[MAXSYMBOLS];
  static double Volumes[MAXSYMBOLS], Lots[MAXSYMBOLS];
  int i, MinPos, Tmp = DIRECTION;
  double PriceBid = 1, PriceAsk = 1;
  double Vol, VolSum = 0;

  double ChannelHigh = 1;
  double ChannelLow = 1;

  double ProfitPrice = 0;

  for (i = 0; i < AmountSymbols; i++)
  {
    Lots[i] = GetLot(Symbols[i]);

    PosBid[i] = 0;
    PosAsk[i] = 0;

    if (ArbitrageVector[i] == DIRECTION)
    {
      PriceBid *= SymbolBids[i][PosBid[i]] * (1 - Commission);
      PriceAsk *= SymbolAsks[i][PosAsk[i]] * (1 + Commission);
    }
    else // (ArbitrageVector[i] == -DIRECTION)
    {
      PriceBid /= SymbolAsks[i][PosAsk[i]] * (1 + Commission);
      PriceAsk /= SymbolBids[i][PosBid[i]] * (1 - Commission);
    }
  }

  if (PriceAsk < ChannelLow)
    Tmp = -DIRECTION;

  for (i = 0; i < AmountSymbols; i++)
    if (ArbitrageVector[i] == Tmp)
      Volumes[i] = SymbolBidVols[i][PosBid[i]] / Lots[i];
    else // (ArbitrageVector[i] == -Tmp)
      Volumes[i] = SymbolAskVols[i][PosAsk[i]] / Lots[i];

  while ((PriceBid > ChannelHigh) || (PriceAsk < ChannelLow))
  {
    MinPos = ArrayMinimum(Volumes, AmountSymbols);
    Vol = Volumes[MinPos];

    for (i = 0; i < AmountSymbols; i++)
    {
      VolSum += Vol;

      Volumes[i] -= Vol;
    }

    if (PriceBid > ChannelHigh)
      ProfitPrice += (PriceBid - ChannelHigh) * Vol;
    else // (PriceAsk < ChannelLow)
      ProfitPrice += (PriceAsk - ChannelLow) * Vol;

    if (ArbitrageVector[MinPos] == Tmp)
    {
      PosBid[MinPos]++;

      if (PosBid[MinPos] == SymbolAmountBids[MinPos])
        break;

      Volumes[MinPos] = SymbolBidVols[MinPos][PosBid[MinPos]] / Lots[MinPos];

      if (PriceBid > ChannelHigh)
        PriceBid *= SymbolBids[MinPos][PosBid[MinPos]] / SymbolBids[MinPos][PosBid[MinPos] - 1];
      else // (PriceAsk < ChannelLow)
        PriceAsk /= SymbolBids[MinPos][PosBid[MinPos]] / SymbolBids[MinPos][PosBid[MinPos] - 1];
    }
    else // (ArbitrageVector[MinPos] == -Tmp)
    {
      PosAsk[MinPos]++;

      if (PosAsk[MinPos] == SymbolAmountAsks[MinPos])
        break;

      Volumes[MinPos] = SymbolAskVols[MinPos][PosAsk[MinPos]] / Lots[MinPos];

      if (PriceBid > ChannelHigh)
        PriceBid /= SymbolAsks[MinPos][PosAsk[MinPos]] / SymbolAsks[MinPos][PosAsk[MinPos] - 1];
      else // (PriceAsk < ChannelLow)
        PriceAsk *= SymbolAsks[MinPos][PosAsk[MinPos]] / SymbolAsks[MinPos][PosAsk[MinPos] - 1];
    }
  }

  for (i = 0; i < AmountSymbols; i++)
    if (ArbitrageVector[i] == Tmp)
      NewVolumes[i] = -VolSum * Lots[i];
    else // (ArbitrageVector[i] == -Tmp)
      NewVolumes[i] = VolSum * Lots[i];

  if (VolSum != 0)
    ProfitPrice /= VolSum;

  return(ProfitPrice);
}

