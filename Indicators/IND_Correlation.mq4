//IND_Correlation - индикатор для MetaTrader 4
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_color1 Red
#property indicator_color2 Blue
#property indicator_width1 2
#property indicator_width2 1
#property indicator_minimum -1
#property indicator_maximum 1

#define TWO_SYMBOLS 2

#define MAX_POINTS 1000000

extern string Symbol1 = "EURUSD";
extern string Symbol2 = "GBPUSD";
extern int Depth = 288;
extern int Shift = 0;
extern double ExpKoef = 0.01;

string Symbols[TWO_SYMBOLS];
double BaseMatrix[TWO_SYMBOLS][MAX_POINTS], MOMatrix[TWO_SYMBOLS][MAX_POINTS];
double CvarMatrix[TWO_SYMBOLS][TWO_SYMBOLS];
double Means[TWO_SYMBOLS], SVector[TWO_SYMBOLS];
int Times[MAX_POINTS], Shifts[TWO_SYMBOLS];
int MatrixRows;
int CurrPos, CurrTime;
double Exp;

double Buffer[], Buffer2[];

datetime GetStartTime( datetime StartTime )
{
  datetime Tmp;
  int Pos;

  for (int i = 0; i < TWO_SYMBOLS; i++)
  {
    Pos = iBarShift(Symbols[i], Period(), StartTime);
    Tmp = iTime(Symbols[i], Period(), Pos);

    if (Tmp > StartTime)
      StartTime = Tmp;
  }

  return(StartTime);
}

double GetPrice( string Symb, int time )
{
  double Price;

  Price = iClose(Symb, Period(), iBarShift(Symb, Period(), time));

  return(Price);
}

int GetNextTime( int CurrTime )
{
  static int Pos[TWO_SYMBOLS];
  int i, MinTime, Tmp = -1;

  for (i = 0; i < TWO_SYMBOLS; i++)
  {
    Pos[i] = iBarShift(Symbols[i], Period(), CurrTime) - 1;

    if (Pos[i] >= 0)
      Tmp = i;
  }

  if (Tmp < 0)
    return(Time[0]);

  MinTime = iTime(Symbols[Tmp], Period(), Pos[Tmp]);

  i = Tmp - 1;

  while (i >= 0)
  {
    if (Pos[i] >= 0)
    {
      Tmp = iTime(Symbols[i], Period(), Pos[i]);

      if (Tmp < MinTime)
        MinTime = Tmp;
    }

    i--;
  }

  return(MinTime);
}

void GetBaseMatrix()
{
  int i, NextTime;

  NextTime = GetNextTime(CurrTime);

  while (NextTime < Time[0])
  {
    CurrTime = NextTime;

    for (i = 0; i < TWO_SYMBOLS; i++)
      BaseMatrix[i][MatrixRows + Shifts[i]] = MathLog(GetPrice(Symbols[i], CurrTime));

    Times[MatrixRows] = CurrTime;

    MatrixRows++;

    NextTime = GetNextTime(CurrTime);
  }

  return;
}

void GetMeans( int Pos, int Len)
{
  int i, j;
  double Sum;

  for (i = 0; i < TWO_SYMBOLS; i++)
  {
    Sum = 0;

    for (j = Pos; j > Pos - Len; j--)
      Sum += BaseMatrix[i][j];

    Means[i] = Sum / Len;
  }

  return;
}

void GetMOMatrix( int Pos, int Len)
{
  int i, j;

  for (i = 0; i < TWO_SYMBOLS; i++)
    for (j = Pos; j > Pos - Len; j--)
      MOMatrix[i][j] = BaseMatrix[i][j] - Means[i];

  return;
}

void GetCvarMatrix( int Pos, int Len )
{
  int i, j, k;
  double Cvar;

  GetMeans(Pos, Len);
  GetMOMatrix(Pos, Len);

  for (i = 0; i < TWO_SYMBOLS; i++)
  {
     Cvar = 0;

     for (k = Pos; k > Pos - Len; k--)
       Cvar += MOMatrix[i][k] * MOMatrix[i][k];

     CvarMatrix[i][i] = Cvar / Len;
  }

  Cvar = 0;

  for (k = Pos; k > Pos - Len; k--)
    Cvar += MOMatrix[0][k] * MOMatrix[1][k];

  Cvar /= Len;

  CvarMatrix[0][1] = Cvar;

  return;
}

bool RealSymbol( string Symb )
{
  return(MarketInfo(Symb, MODE_BID) != 0);
}


string iIF( bool Cond, string Str1, string Str2 )
{
  if (Cond)
    return(Str1);

  return(Str2);
}

void init()
{
  Symbols[0] = iIF(Shift < 0, Symbol2, Symbol1);
  Symbols[1] = iIF(Shift < 0, Symbol1, Symbol2);

  Shifts[0] = 0;
  Shifts[1] = MathAbs(Shift);

  for (int i = 0; i < TWO_SYMBOLS; i++)
    if (!RealSymbol(Symbols[i]))
      Symbols[i] = Symbol();

  IndicatorDigits(8);
  SetIndexStyle(0, DRAW_LINE, DRAW_LINE);
  SetIndexBuffer(0, Buffer);
  SetIndexBuffer(1, Buffer2);
  SetIndexLabel(0, "Correlation");
  SetIndexLabel(1, "Exponential (ExpKoef = " + DoubleToStr(ExpKoef, 3) + ")");
  IndicatorShortName("Correlation (" + Depth + " bars): " + Symbols[0] + "(t) && " + Symbols[1] + "(t - " + Shifts[1] + ")");

  CurrTime = GetStartTime(0);
  MatrixRows = 0;

  GetBaseMatrix();

  CurrPos = Depth + Shifts[1];

  GetCvarMatrix(CurrPos - 1, Depth);
  Exp = GetCorrelation();

  return;
}

void GetNextMeans( int Pos, int Len )
{
  int Pos2 = Pos - Len;

  for (int i = 0; i < TWO_SYMBOLS; i++)
  {
    SVector[i] = (BaseMatrix[i][Pos2] - BaseMatrix[i][Pos]) / Len;
    Means[i] -= SVector[i];
  }

  return;
}

void GetNextCvarMatrix2( int Pos, int Len )
{
  int i, j;
  int Pos2 = Pos - Len;
  double Tmp1[TWO_SYMBOLS], Tmp2[TWO_SYMBOLS], Tmp3[TWO_SYMBOLS];

  GetNextMeans(Pos, Len);

  for (i = 0; i < TWO_SYMBOLS; i++)
  {
    Tmp1[i] = SVector[i];
    Tmp2[i] = BaseMatrix[i][Pos] - Means[i];
    Tmp3[i] = BaseMatrix[i][Pos2] - Means[i];

    CvarMatrix[i][i] += Tmp1[i] * Tmp1[i] + (Tmp2[i] * Tmp2[i] - Tmp3[i] * Tmp3[i]) / Len;

    if (CvarMatrix[i][i] < 0)
      CvarMatrix[i][i] = 0;
  }

  CvarMatrix[0][1] += Tmp1[0] * Tmp1[1] + (Tmp2[0] * Tmp2[1] - Tmp3[0] * Tmp3[1]) / Len;

  return;
}

double GetCorrelation()
{
  double Res = 0;
  double Var = MathSqrt(CvarMatrix[0][0] * CvarMatrix[1][1]);

  if (Var != 0)
    Res = CvarMatrix[0][1] / Var;

  return(Res);
}

void start()
{
  static int PrevTime = 0;
  double Corr;
  int Pos;

  if (PrevTime == 0)
  {
    PrevTime = Time[0];

    while (CurrPos < MatrixRows)
    {
      GetNextCvarMatrix2(CurrPos, Depth);

      Corr = GetCorrelation();
      Exp = Corr * ExpKoef + Exp * (1 - ExpKoef);

      Pos = iBarShift(Symbol(), Period(), Times[CurrPos]);
      Buffer[Pos] = Corr;
      Buffer2[Pos] = Exp;

      CurrPos++;
    }
  }

  if (PrevTime != Time[0])
  {
    PrevTime = Time[0];

    GetBaseMatrix();

    while (CurrPos < MatrixRows)
    {
      GetCvarMatrix(CurrPos, Depth);

      Corr = GetCorrelation();
      Exp = Corr * ExpKoef + Exp * (1 - ExpKoef);

      Pos = iBarShift(Symbol(), Period(), Times[CurrPos]);
      Buffer[Pos] = Corr;
      Buffer2[Pos] = Exp;

      CurrPos++;
    }
  }

  return;
}