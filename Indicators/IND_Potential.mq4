//https://www.mql5.com/ru/code/10468
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_color1 Red
#property indicator_color2 Lime
#property indicator_color3 Blue
#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 2
#property indicator_minimum 0

#define MAX_POINTS 1000000

extern datetime StartTime = D'2011.01.01';
extern int Spread = 20;
extern int Profit = 20;
extern double ExpKoef = 0.05;

double PotentialSum[];
int PotentialCount[];

double Buffer[], Buffer2[], Buffer3[];

void init()
{
  int TmpStep, Tmp, TmpHigh, Pos = 0;

  if (Spread < Profit)
  {
    TmpStep = Spread;
    TmpHigh = Profit;
  }
  else
  {
    TmpStep = Profit;
    TmpHigh = Spread;
  }

  SetIndexBuffer(0, Buffer);
  SetIndexStyle(0, DRAW_HISTOGRAM);

  SetIndexBuffer(1, Buffer2);
  SetIndexStyle(1, DRAW_LINE);

  SetIndexBuffer(2, Buffer3);
  SetIndexStyle(2, DRAW_LINE);

  while(Tmp < TmpHigh)
  {
    SetLevelValue(Pos, Tmp);

    Tmp += TmpStep;
    Pos++;
  }

  SetLevelValue(Pos, TmpHigh);

  SetIndexLabel(1, "Exponential (ExpKoef = " + DoubleToStr(ExpKoef, 2) + ")");
  SetIndexLabel(2, "Average (StartTime " + TimeToStr(StartTime, TIME_DATE) + ")");
  IndicatorShortName(WindowExpertName() + ": Spread = " + Spread + ", Profit = " + Profit + ", ExpKoef = " + DoubleToStr(ExpKoef, 2));

  Profit += Spread;

  ArrayResize(PotentialCount, 1440 / Period());
  ArrayResize(PotentialSum, 1440 / Period());

  return;
}

int GetCount( int& Count[] )
{
  bool FlagUP = TRUE;
  int Min, Max = 0;
  int Amount = 0;
  int NTime;
  int PriceLow, PriceHigh;
  int Pos = iBarShift(Symbol(), Period(), StartTime);

  for (int i = Pos; i >= 0; i--)
  {
    PriceLow = Low[i] / Point + 0.1;
    PriceHigh = High[i] / Point + 0.1;

    if (FlagUP)
    {
      if (PriceHigh > Max)
      {
        Max = PriceHigh;
        NTime = i;
      }
      else if (Max - PriceLow >= Profit)
      {
        Count[Amount] = NTime;
        Amount++;

        FlagUP = FALSE;
        Min = PriceLow;
        NTime = i;
      }
    }
    else // (FlagUP == FALSE)
    {
      if (PriceLow < Min)
      {
        Min = PriceLow;
        NTime = i;
      }
      else if (PriceHigh - Min >= Profit)
      {
        Count[Amount] = NTime;
        Amount++;

        FlagUP = TRUE;
        Max = PriceHigh;
        NTime = i;
      }
    }
  }

  Count[Amount] = NTime;
  Amount++;

  return(Amount);
}

void DrawIndicator()
{
  static int Count[MAX_POINTS];
  int Amount = GetCount(Count);
  int Time1 = Count[0], Time2, TmpTime;
  bool Flag = TRUE;
  double Tmp, Tmp2 = 0;
  int i, j;

  ArrayInitialize(PotentialCount, 0);
  ArrayInitialize(PotentialSum, 0);

  for (i = 1; i < Amount; i++)
  {
    Time2 = Count[i];

    if (Flag)
      Tmp = ((High[Time1] - Low[Time2]) / Point - Spread) / (Time1 - Time2);
    else
      Tmp = ((High[Time2] - Low[Time1]) / Point - Spread) / (Time1 - Time2);

    for (j = Time1; j > Time2; j--)
    {
      Tmp2 = Tmp2 * (1 - ExpKoef) + Tmp * ExpKoef;

      TmpTime = Time[j];
      TmpTime = (TimeHour(TmpTime) * PERIOD_H1 + TimeMinute(TmpTime)) / Period();

      PotentialCount[TmpTime]++;
      PotentialSum[TmpTime] += Tmp;

      Buffer[j] = Tmp;
      Buffer2[j] = Tmp2;
      Buffer3[j] = PotentialSum[TmpTime] / PotentialCount[TmpTime];
    }

    Time1 = Time2;
    Flag = !Flag;
  }

  return;
}

void start()
{
  static int PrevTime = 0;

  if (Time[0] == PrevTime)
    return;

  PrevTime = Time[0];

  DrawIndicator();

  return;
}