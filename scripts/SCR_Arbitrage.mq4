#include <Simple-Arbitrage.mqh>
// #include <../Simple-Arbitrage/Threads.mqh>

#define PAUSE 10

extern double CommissionProcent = 0.25;

void init()
{
  CommissionProcent /= 100;

//  MasterInitThreads();

  start();

  return;
}

void deinit()
{
  DeinitLevel2();
//  MasterDeinitThreads();

  return;
}

void CommentVPS( string Str, int Pause = 1000 )
{
  static int PrevTime = 0;
  int CurrTime = GetTickCount();

  if (PrevTime == 0)
    PrevTime = GetTickCount();

  if (CurrTime - PrevTime > Pause) // специально упустил MathAbs на случай ((PrevTime == 0) && (CurrTime < 0)) == TRUE.
  {
    Comment(Str);

    PrevTime = CurrTime;
  }

  return;
}

void ArbitrageString( string &Str, string &Symbols[], int AmountSymbols, double ProfitPrice, int &ArbitrageVector[], double &Volumes[] )
{
  int Tmp = DIRECTION;
  int i, j, Min = LEVEL2_MAXDEPTH;

  Str = "";

  if (ProfitPrice < 0)
    Tmp = -DIRECTION;

  for (i = 0; i < AmountSymbols; i++)
  {
    Str = Str + Symbols[i] + " " + ArbitrageVector[i] + ", Volume = " + DoubleToStr(Volumes[i], 8) + "\n";

    if (ArbitrageVector[i] == Tmp)
    {
      if (SymbolAmountBids[i] < Min)
        Min = SymbolAmountBids[i];
    }
    else if (SymbolAmountAsks[i] < Min)
      Min = SymbolAmountAsks[i];
  }

  for (i = 0; i < Min; i++)
  {
    for (j = 0; j < AmountSymbols; j++)
      if (ArbitrageVector[j] == Tmp)
        Str = Str + DoubleToStr(SymbolBids[j][i], 5) + "  " + DoubleToStr(SymbolBidVols[j][i], 8) + "     ";
      else // (ArbitrageVector[j] == -Tmp)
        Str = Str + DoubleToStr(SymbolAsks[j][i], 5) + "  " + DoubleToStr(SymbolAskVols[j][i], 8) + "     ";

    Str = Str + "\n";
  }

  return;
}

string StrNumToLen( string Num, int Len )
{
  Len -= StringLen(Num);

  while (Len > 0)
  {
    Num = "0" + Num;
    Len--;
  }

  return(Num);
}

void SaveArbitrage(string &StrLevel2, string &StrHead, int CountArbitrage, string &Symbols[], int AmountSymbols )
{
  string Str = Symbols[0];
  string StrCount = StrNumToLen(CountArbitrage, 4);

  for (int i = 1; i < AmountSymbols; i++)
    Str = Str + "-" + Symbols[i];

  int handle = FileOpen(WindowExpertName() + "//" + Str + "_Level2_" + StrCount + ".txt", FILE_CSV|FILE_WRITE);

  FileWrite(handle, StrHead);
  FileWrite(handle, StrLevel2);

  FileClose(handle);

  handle = FileOpen(WindowExpertName() + "//" + Str + "_Heads.txt", FILE_CSV|FILE_READ|FILE_WRITE);

  FileSeek(handle, 0, SEEK_END);

  FileWrite(handle, StrCount + ": " + StrHead);

  FileClose(handle);

  return;
}


#define PRINT_DEPTH 5

void SetArbitrage( string &Symbols[], int AmountSymbols, double Commission = -1 )
{
  static int ArbitrageVector[MAXSYMBOLS];
  static double Volumes[MAXSYMBOLS];
  string Str = WindowExpertName() + " " + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS);
  int i;

  int NewTime;
  static int PrevTime = 0;
  static double PrevVolume = 0;

  static double PrevProfitPrice = 0;
  double ProfitPrice;

  static int CountArbitrage = 0;
  static string Str2 = "", Str3 = "";

  if (CheckArbitrage(Symbols, ArbitrageVector, AmountSymbols))
  {
    if (GetLevels2(Symbols, AmountSymbols))
    {
      if (Commission < 0)
        Commission = CommissionProcent;

      ProfitPrice = GetVolumes(Symbols, ArbitrageVector, AmountSymbols, Commission, Volumes);

/************** PRINT **************************/
      if (Volumes[0] != 0)
      {
        if (PrevTime == 0)
        {
          PrevTime = GetTickCount();

          PrevVolume = Volumes[0];
          PrevProfitPrice = ProfitPrice;

          ArbitrageString(Str2, Symbols, AmountSymbols, ProfitPrice, ArbitrageVector, Volumes);
        }

        if ((PrevProfitPrice != 0) && (PrevProfitPrice != ProfitPrice))
        {

          NewTime = GetTickCount();

          Str3 = TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ", Length = " + DoubleToStr(NewTime - PrevTime, 0) + " ms., ProfitPrice = " + DoubleToStr(PrevProfitPrice, 8) + ", Volume = " + DoubleToStr(PrevVolume, 8);

          CountArbitrage++;

          SaveArbitrage(Str2, Str3, CountArbitrage, Symbols, AmountSymbols);

          Print(CountArbitrage + ": " + Str3);

          ArbitrageString(Str2, Symbols, AmountSymbols, ProfitPrice, ArbitrageVector, Volumes);

          PrevProfitPrice = ProfitPrice;
          PrevVolume = Volumes[0];

          PrevTime = NewTime;
        }

        for (int j = 0; j < AmountSymbols; j++)
        {
          Str = Str + "\n" + Symbols[j] + ":\n";

//          for (i = SymbolAmountAsks[j] - 1; i >= 0 ; i--)
          for (i = PRINT_DEPTH - 1; i >= 0; i--)
            Str = Str + DoubleToStr(SymbolAsks[j][i], 5) + " " + DoubleToStr(SymbolAskVols[j][i], 8) + "\n";

          Str = Str + "\n";

//          for (i = 0; i < SymbolAmountBids[j]; i++)
          for (i = 0; i < PRINT_DEPTH; i++)
            Str = Str + DoubleToStr(SymbolBids[j][i], 5) + " " + DoubleToStr(SymbolBidVols[j][i], 8) + "\n";
        }

        for (i = 0; i < AmountSymbols; i++)
          Str = Str + Symbols[i] + " " + ArbitrageVector[i] + ", Volume = " + DoubleToStr(Volumes[i], 8) + "\n";

        CommentVPS(Str);
      }
      else if (PrevTime != 0)
      {
        Str3 = TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ", Length = " + DoubleToStr(GetTickCount() - PrevTime, 0) +
        " ms., ProfitPrice = " + DoubleToStr(PrevProfitPrice, 8) + ", Volume = " + DoubleToStr(PrevVolume, 8) + "\n";

        CountArbitrage++;

        SaveArbitrage(Str2, Str3, CountArbitrage, Symbols, AmountSymbols);

        Print(CountArbitrage + ": " + Str3);

        PrevTime = 0;
        PrevProfitPrice = 0;
      }
/**********************************************/

//      TradeArbitrage(Symbols, AmountSymbols, Volumes);
    }
  }

  return;
}

void start()
{
//  string Symbols[MAXSYMBOLS] = {"BTCUSD", "LTCUSD", "LTCBTC", EMPTY_CURRENCY};
  string Symbols[MAXSYMBOLS] = {"BTCUSD", "NMCUSD", "NMCBTC", EMPTY_CURRENCY};
  int AmountSymbols = 3;
//  string Symbols[MAXSYMBOLS] = {"LTCUSD", "LTCBTC", "NMCUSD", "NMCBTC"};
//  int AmountSymbols = 4;

  InitLevel2(Symbols);

  while (!IsStopped())
  {
    SetArbitrage(Symbols, AmountSymbols);

    Sleep(PAUSE);
  }

  Comment("");

  return;
}