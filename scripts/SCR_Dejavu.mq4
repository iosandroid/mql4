#property show_inputs

#define pi 3.14159265358979323846

#define PAUSE 50

#define AMOUNT_OBJECT 5
#define MAX_AMOUNT_SAMPLES 1000
#define FONT_SIZE 13
#define STEP_TEXT 20

extern datetime StartDate = D'2010.11.01';
extern double Limit = 0.95;
extern double MinStep = 0.2;
extern int InitInterval = 288;
extern int Depth = 100;
extern double Alpha = 0;
extern int Pause = 250;
extern color ColorLine = Red;
extern color ColorText1 = Yellow;
extern color ColorText2 = Orange;

double Prices[], PricesHigh[], PricesLow[];
double StDevs[], Means[];
double Shablon[];
double Mean, StDev, Var;
int Times[1] = {0};

int Coord1, Coord2, Shift;
string Str1[AMOUNT_OBJECT] = {"Interval = ", "History = ", "Best Sample = ", "Amount of Samples = ", "Time of calculation = "};
string Str2[AMOUNT_OBJECT] = {"", "", "", "", ""};
int ObjXCoord[AMOUNT_OBJECT] = {70, 70, 105, 155, 155};

string WHandle;

bool GetChange()
{
  int Coords[2], Interval, Pos;
  bool Res = FALSE;

  Coords[0] = ObjectGet(WHandle + "BeginInterval", OBJPROP_TIME1);
  Coords[1] = ObjectGet(WHandle + "EndInterval", OBJPROP_TIME1);

  Interval = iBarShift(Symbol(), Period(), Coord1) - iBarShift(Symbol(), Period(), Coord2);
  Pos = iBarShift(Symbol(), Period(), Coords[1]);

  if (Coord1 != Coords[0])
  {
    Coord1 = Coords[0];
    SetVertLine("BeginInterval", Coord1);

    Res = TRUE;
  }
  else if (Coord2 != Coords[1])
  {
    Shift = WindowBarsPerChart() + Pos - WindowFirstVisibleBar();

    if (Coords[1] > Time[0])
      Pos = 0;

    Coord1 = Time[Pos + Interval];
    Coord2 = Time[Pos];

    SetVertLine("BeginInterval", Coord1);
    SetVertLine("EndInterval", Coord2);

    Res = TRUE;
  }
  else if (WindowBarsPerChart() + Pos - WindowFirstVisibleBar() != Shift)
  {
    Pos = WindowFirstVisibleBar() - WindowBarsPerChart() + Shift;

    if (Pos < 0)
      Pos = 0;

    Coord2 = Time[Pos];
    Coord1 = Time[Pos + Interval];

    SetVertLine("BeginInterval", Coord1);
    SetVertLine("EndInterval", Coord2);

    Res = TRUE;
  }

  if (Res)
  {
    Interval = iBarShift(Symbol(), Period(), Coord1) - iBarShift(Symbol(), Period(), Coord2) + 1;

    ObjectSetText(WHandle + "0", Interval + " bars (" + TimeToStr(Coord1) + " - " + TimeToStr(Coord2) + ") - NOT CALC.",
                  FONT_SIZE, "Times New Roman", ColorText2);

    WindowRedraw();
  }

  return(Res);
}

bool GetChange2( int Pause )
{
  static bool Change = FALSE;
  static int ChangeTime = 0;

  if (GetChange())
  {
    ChangeTime = GetTickCount();
    Change = TRUE;

    return(FALSE);
  }
  else if (Change)
    if (GetTickCount() - ChangeTime > Pause)
    {
      Change = FALSE;

      return(TRUE);
    }

  return(FALSE);
}

void RealFFT(double& a[], int tnn, bool inversefft = FALSE)
{
  double twr, twi, twpr, twpi, twtemp;
  double ttheta, theta = pi;
  int i, j, m;
  int i1, i2, i3, i4;
  double h1r, h1i, h2r, h2i;
  double wrs, wis;
  int n = tnn, nn = n >> 1;
  int mmax = 2, istep = 4;
  double wtemp, wr, wi, wpr, wpi;
  double tempr, tempi;
  int TmpINT;
  double TmpDOUBLE, Tmp1, Tmp2, Tmp3, Tmp4;

  if (tnn == 1)
    return;

  if (!inversefft)
  {
    j = 1;

    for(i = 1; i < n; i += 2)
    {
      if (j > i)
      {
        tempr = a[j-1];
        tempi = a[j];

        a[j-1] = a[i-1];
        a[j] = a[i];

        a[i-1] = tempr;
        a[i] = tempi;
      }

      m = nn;

      while ((m >= 2) && (j > m))
      {
        j -= m;
        m >>= 1;
      }

      j += m;
    }

    while (n > mmax)
    {
      TmpDOUBLE = MathSin(theta / 2);
      wpr = -2.0 * TmpDOUBLE * TmpDOUBLE;
      wpi = MathSin(theta);
      wr = 1.0;
      wi = 0.0;

      TmpINT = mmax + 1;

      for (m = 1; m < mmax; m += 2)
      {
        j = TmpINT;

        for(i = m; i <= n; i += istep)
        {
          Tmp1 = a[j - 1];
          Tmp2 = a[j];

          tempr = wr * Tmp1 - wi * Tmp2;
          tempi = wr * Tmp2 + wi * Tmp1;

          a[j-1] = a[i-1] - tempr;
          a[j] = a[i] - tempi;
          a[i - 1] += tempr;
          a[i] += tempi;

          j += istep;
        }

        wtemp = wr;
        wr = wr * wpr - wi * wpi + wr;
        wi = wi * wpr + wtemp * wpi + wi;

        TmpINT += 2;
      }

      mmax = istep;
      istep <<= 1;
      theta /= 2;
    }

    TmpDOUBLE = MathSin(theta / 2);

    twpr = -2.0 * TmpDOUBLE * TmpDOUBLE;
    twpi = MathSin(2.0 * pi / tnn);
    twr = 1.0 + twpr;
    twi = twpi;

    i2 = 3;
    i3 = tnn - 2;
    i4 = tnn - 1;

    for (i1 = 2; i1 <= nn; i1 += 2, i2 += 2, i3 -= 2, i4 -= 2)
    {
      wrs = twr;
      wis = twi;

      Tmp1 = a[i1];
      Tmp2 = a[i2];
      Tmp3 = a[i3];
      Tmp4 = a[i4];

      h1r = Tmp1 + Tmp3;
      h1i = Tmp2 - Tmp4;
      h2r = Tmp2 + Tmp4;
      h2i = Tmp3 - Tmp1;

      a[i1] = h1r + wrs * h2r - wis * h2i;
      a[i2] = h1i + wrs * h2i + wis * h2r;
      a[i3] = h1r - wrs * h2r + wis * h2i;
      a[i4] = wrs * h2i + wis * h2r - h1i;

      twtemp = twr;
      twr = twr * twpr - twi * twpi + twr;
      twi = twi * twpr + twtemp * twpi + twi;
    }

    h1r = a[0];
    a[0] = (h1r + a[1]) * 2;
    a[1] = (h1r - a[1]) * 2;
  }
  else
  {
    ttheta = -2.0 * pi / tnn;
    TmpDOUBLE = MathSin(ttheta / 2);

    twpr = -2.0 * TmpDOUBLE * TmpDOUBLE;
    twpi = MathSin(ttheta);
    twr = 1.0 + twpr;
    twi = twpi;

    i2 = 3;
    i3 = tnn - 2;
    i4 = tnn - 1;

    for (i1 = 2; i1 <= nn; i1 += 2, i2 += 2, i3 -= 2, i4 -= 2)
    {
      wrs = twr;
      wis = twi;

      Tmp1 = a[i1];
      Tmp2 = a[i2];
      Tmp3 = a[i3];
      Tmp4 = a[i4];

      h1r = Tmp1 + Tmp3;
      h1i = Tmp2 - Tmp4;
      h2r = -Tmp2 - Tmp4;
      h2i = Tmp1 - Tmp3;

      a[i1] = h1r + wrs * h2r - wis * h2i;
      a[i2] = h1i + wrs * h2i + wis * h2r;
      a[i3] = h1r - wrs * h2r + wis * h2i;
      a[i4] = -h1i + wrs * h2i + wis * h2r;

      twtemp = twr;
      twr = twr * twpr - twi * twpi + twr;
      twi = twi * twpr + twtemp * twpi + twi;
    }

    h1r = a[0];
    a[0] = h1r + a[1];
    a[1] = h1r - a[1];

    j = 1;

    for (i = 1; i < n; i += 2)
    {
      if (j > i)
      {
        tempr = a[j - 1];
        tempi = a[j];

        a[j - 1] = a[i - 1];
        a[j] = a[i];

        a[i - 1] = tempr;
        a[i] = tempi;
      }

      m = nn;

      while ((m >= 2) && (j > m))
      {
        j -= m;
        m >>= 1;
      }

      j += m;
    }

    theta = -theta;

    while (n > mmax)
    {
      TmpDOUBLE = MathSin(theta / 2);
      wpr = -2.0 * TmpDOUBLE * TmpDOUBLE;
      wpi = MathSin(theta);
      wr = 1.0;
      wi = 0.0;

      TmpINT = mmax + 1;

      for (m = 1; m < mmax; m += 2)
      {
        j = TmpINT;

        for (i = m; i <= n; i += istep)
        {
          Tmp1 = a[j - 1];
          Tmp2 = a[j];

          tempr = wr * Tmp1 - wi * Tmp2;
          tempi = wr * Tmp2 + wi * Tmp1;

          a[j - 1] = a[i - 1] - tempr;
          a[j] = a[i] - tempi;
          a[i - 1] += tempr;
          a[i] += tempi;

          j += istep;
        }

        wtemp = wr;
        wr = wr*wpr-wi*wpi+wr;
        wi = wi*wpr+wtemp*wpi+wi;

        TmpINT += 2;
      }

      mmax = istep;
      istep <<= 1;
      theta /= 2;
    }
  }
}

void GetCorrelationFFT( double &Corr[], double &signal[], double &pattern[], bool FlagChange = FALSE )
{
  static double a1[], a2[];
  static int nl = 2;
  int Tmp, i = 1;
  double t1, t2, t3, t4;
  int signallen = ArraySize(signal);
  int patternlen = ArraySize(pattern);

  if ((nl < signallen + patternlen) || ((nl >> 1) >=  signallen + patternlen))
  {
    nl = signallen + patternlen;

    while(i < nl)
      i <<= 1;

    nl = i;

    FlagChange = TRUE;
  }

  if (FlagChange)
  {
    if (i > 1)
    {
      ArrayResize(a1, nl);
      ArrayResize(a2, nl);
    }

    ArrayInitialize(a1, 0);
    ArrayCopy(a1, signal, 0, 0, signallen);

    RealFFT(a1, nl, FALSE);
  }

  ArrayInitialize(a2, 0);
  ArrayCopy(a2, pattern);

  RealFFT(a2, nl, FALSE);

  a2[0] *= a1[0];
  a2[1] *= a1[1];

  for(i = 2; i < nl - 1; i += 2)
  {
    t1 = a1[i];
    t2 = a1[i + 1];
    t3 = a2[i];
    t4 = a2[i + 1];

    a2[i] = t1*t3+t2*t4;
    a2[i+1] = t2*t3-t1*t4;
  }

  RealFFT(a2, nl, TRUE);

  for(i = 0; i < patternlen - 1; i++)
    Corr[i] = 0;

  Tmp = (nl << 2) * patternlen;

  for (i = 0; i <= signallen - patternlen; i++)
    if (StDevs[i + patternlen - 1] == 0)
      Corr[i + patternlen - 1] = 0;
    else
      Corr[i + patternlen - 1] = a2[i] / (StDevs[i + patternlen - 1] * Tmp);

  return;
}

int GetPrices( double &Array[], double &ArrayHigh[],  double &ArrayLow[], double Alpha )
{
  int Size = iBarShift(Symbol(), Period(), StartDate) + 1;

  ArrayResize(Array, Size);
  ArrayResize(ArrayHigh, Size);
  ArrayResize(ArrayLow, Size);
  ArrayResize(Times, Size);

  double Tmp = MathLog(Close[Size - 1]);

  for (int i = 0; i < Size; i++)
  {
    Tmp = MathLog(Close[Size - i - 1]) * (1 - Alpha) + Tmp * Alpha;
    Array[i] = Tmp;

    ArrayHigh[i] = MathLog(High[Size - i - 1]);
    ArrayLow[i] = MathLog(Low[Size - i - 1]);

    Times[i] = Time[Size - i - 1];
  }

  return(Size);
}

void GetShablon( double &ArraySource[], double &ArrayDestination[], int Begin, int End )
{
  int j = 0;

  ArrayResize(ArrayDestination, End - Begin + 1);

  for (int i = Begin ; i <= End; i++)
  {
    ArrayDestination[j] = ArraySource[i];

    j++;
  }

  return;
}

double GetCorr( double &Array[], int Pos, double &Shablon[] )
{
  int Size = ArraySize(Shablon);
  double Sum = 0, StDevArray = StDevs[Pos];

  if (StDevArray == 0)
    return(0);

  Pos -= Size - 1;

  for (int i = 0; i < Size; i++)
    Sum += Array[Pos + i] * Shablon[i];

  return(Sum / (StDevArray * Size));
}

void GetCorrelationClassic( double &Corr[], double &Signal[], double &Pattern[] )
{
  int i;
  int PatternLen = ArraySize(Pattern);
  int SignalLen = ArraySize(Signal);

  for (i = 0; i < PatternLen - 1; i++)
    Corr[i] = 0;

  for (i = PatternLen - 1; i < SignalLen; i++)
    Corr[i] = GetCorr(Signal, i, Pattern);

  return;
}

void GetStDev( int Pos, int Len )
{
  int i;
  double Tmp = 0, Tmp2;

  Var = 0;

  for (i = Pos; i > Pos - Len; i--)
    Tmp += Prices[i];

  Tmp /= Len;

  Means[Pos] = Tmp;

  for (i = Pos; i > Pos - Len; i--)
  {
    Tmp2 = Prices[i] - Tmp;

    Var += Tmp2 * Tmp2;
  }

  Var /= Len;

  StDevs[Pos] = MathSqrt(Var);

  return;
}

void GetNextStDev( int Pos, int Len )
{
  int Pos2 = Pos - Len;
  double Tmp, Tmp1, Tmp2, Tmp3;

  Tmp1 = (Prices[Pos2] - Prices[Pos]) / Len;
  Tmp = Means[Pos -1] - Tmp1;
  Means[Pos] = Tmp;
  Tmp2 = Prices[Pos] - Tmp;
  Tmp3 = Prices[Pos2] - Tmp;

  Var += Tmp1 * Tmp1 + (Tmp2 * Tmp2 - Tmp3 * Tmp3) / Len;

  if (Var < 0)
    Var = 0;

  StDevs[Pos] = MathSqrt(Var);

  return;
}

void NormalizeVector( double &Vector[] )
{
  int i, SizeVector = ArraySize(Vector);

  Mean = 0;
  StDev = 0;

  for (i = 0; i < SizeVector; i++)
    Mean += Vector[i];

  Mean /= SizeVector;

  for (i = 0; i < SizeVector; i++)
  {
    Vector[i] -= Mean;

    StDev += Vector[i] * Vector[i];
  }

  if (StDev != 0)
  {
    StDev = MathSqrt(StDev / SizeVector);

    for (i = 0; i < SizeVector; i++)
      Vector[i] /= StDev;
  }

  return;
}

double Bench( int SignalLen,  int PatternLen )
{
  static double Koef = 3.5;
  int i = 1, Count = 0;
  int Tmp = SignalLen + PatternLen;

  while (i < Tmp)
  {
    Count++;
    i <<= 1;
  }

  return(Koef * Count * i / (PatternLen * (SignalLen - PatternLen)));
}

void GetCorrelation( double &Corr[], double &Signal[], int Begin, int End, bool FlagChange )
{
  static int NewSize = 0;
  int Size = ArraySize(Signal);

  if ((NewSize != End - Begin + 1) || (FlagChange))
  {
    if (FlagChange)
    {
      ArrayResize(Corr, Size);

      ArrayResize(Means, Size);
      ArrayResize(StDevs, Size);
    }

    NewSize = End - Begin + 1;

    GetStDev(NewSize - 1, NewSize);

    for (int i = NewSize; i < Size; i++)
      GetNextStDev(i, NewSize);
  }

  GetShablon(Prices, Shablon, Begin, End);
  NormalizeVector(Shablon);

  if (Bench(Size, NewSize) < 1)
    GetCorrelationFFT(Corr, Signal, Shablon, FlagChange);
  else
    GetCorrelationClassic(Corr, Signal, Shablon);

  return;
}

int DataToIndicator( double &Corr[], int &MaxPos, double &CorrAvg, double &Shablon[], int Offset )
{
  double MaxCorr, LimitCorr, MinStepCorr;
  double PriceAvg[], PricesAvg[][MAX_AMOUNT_SAMPLES];
  double PriceAvgHigh[], PriceAvgLow[];
  double Min, Max, Current, Tmp;
  double TmpMean, TmpStDev;
  int handle;
  bool FlagUP = TRUE;
  int i, j, Amount = 0;
  double StDevAvg = 0;
  int Size = ArraySize(Corr);
  int NewSize = ArraySize(Shablon);
  int Pos =ArrayMinimum(Corr, Size - 2 * NewSize + 1 - Offset - Depth, NewSize - 1 + Depth);
  MaxPos = ArrayMaximum(Corr, Size - 2 * NewSize + 1 - Offset - Depth, NewSize - 1 + Depth);
  MaxCorr = Corr[MaxPos];

  if (-Corr[Pos] > MaxCorr)
  {
    MaxPos = Pos;
    MaxCorr = -Corr[Pos];
  }

  LimitCorr = MaxCorr * Limit;
  MinStepCorr = MaxCorr * MinStep;

  ArrayResize(PriceAvg, NewSize + Depth * 2);
  ArrayResize(PricesAvg, NewSize + Depth * 2);
  ArrayResize(PriceAvgHigh, NewSize + Depth * 2);
  ArrayResize(PriceAvgLow, NewSize + Depth * 2);

  ArrayInitialize(PriceAvg, 0);
  ArrayInitialize(PriceAvgHigh, -999);
  ArrayInitialize(PriceAvgLow, 999);

  Pos = NewSize - 1 + Depth;
  Min = Corr[Pos];
  Max = Min;

  for (i = NewSize - 1 + Depth; i < Size - NewSize - Offset; i++)
  {
    Current = Corr[i];

    if (FlagUP)
    {
      if (Current > Max)
      {
        Max = Current;
        Pos = i;
      }
      else if (Max - Current > MinStepCorr)
      {
        if (Corr[Pos] >= LimitCorr)
        {
          for (j = -Depth; j < NewSize + Depth; j++)
          {
            Tmp = (Prices[Pos - NewSize + j + 1] - Means[Pos]) / StDevs[Pos];
            PriceAvg[j + Depth] += Tmp;
            PricesAvg[j + Depth][Amount] = Tmp;

            Tmp = (PricesHigh[Pos - NewSize + j + 1] - Means[Pos]) / StDevs[Pos];

            if (Tmp > PriceAvgHigh[j + Depth])
              PriceAvgHigh[j + Depth] = Tmp;

            Tmp = (PricesLow[Pos - NewSize + j + 1] - Means[Pos]) / StDevs[Pos];

            if (Tmp < PriceAvgLow[j + Depth])
              PriceAvgLow[j + Depth] = Tmp;
          }

          Amount++;
        }

        FlagUP = FALSE;
        Min = Current;
        Pos = i;
      }
    }
    else // (FlagUP == FALSE)
    {
      if (Current < Min)
      {
        Min = Current;
        Pos = i;
      }
      else if (Current - Min > MinStepCorr)
      {
        if (-Corr[Pos] >= LimitCorr)
        {
          for (j = -Depth; j < NewSize + Depth; j++)
          {
            Tmp = (Means[Pos] - Prices[Pos - NewSize + j + 1]) / StDevs[Pos];

            PriceAvg[j + Depth] += Tmp;
            PricesAvg[j + Depth][Amount] = Tmp;

            Tmp = (Means[Pos] - PricesLow[Pos - NewSize + j + 1]) / StDevs[Pos];

            if (Tmp > PriceAvgHigh[j + Depth])
              PriceAvgHigh[j + Depth] = Tmp;

            Tmp = (Means[Pos] - PricesHigh[Pos - NewSize + j + 1]) / StDevs[Pos];

            if (Tmp < PriceAvgLow[j + Depth])
              PriceAvgLow[j + Depth] = Tmp;
          }

          Amount++;
        }

        FlagUP = TRUE;
        Max = Current;
        Pos = i;
      }
    }
  }

  for (i = 0; i < NewSize; i++)
  {
    Tmp = PriceAvg[i + Depth];
    StDevAvg += Tmp * Tmp;
  }

  StDevAvg = MathSqrt(StDevAvg * NewSize);
  CorrAvg = 0;

  for (i = 0; i < NewSize; i++)
    CorrAvg += PriceAvg[i + Depth] * Shablon[i];

  CorrAvg /= StDevAvg;

  handle = FileOpen(WHandle + "i.dat", FILE_WRITE|FILE_BIN);

  for (i = -Depth; i < NewSize + Depth; i++)
  {
    TmpMean = PriceAvg[i + Depth] / Amount;
    TmpStDev = 0;

    for (j = 0; j < Amount; j++)
    {
      Tmp = PricesAvg[i + Depth][j] - TmpMean;
      TmpStDev += Tmp * Tmp;
    }

    TmpStDev = MathSqrt(TmpStDev / Amount);

    if (i - NewSize - Offset < 0)
      FileWriteInteger(handle, Times[Size - NewSize - Offset + i]);
    else
      FileWriteInteger(handle, NewSize + Offset - i - 1);

    FileWriteDouble(handle, MathExp(TmpMean * StDev + Mean));
    FileWriteDouble(handle, MathExp((TmpMean + TmpStDev) * StDev + Mean));
    FileWriteDouble(handle, MathExp((TmpMean - TmpStDev) * StDev + Mean));
    FileWriteDouble(handle, MathExp(PriceAvgHigh[i + Depth] * StDev + Mean));
    FileWriteDouble(handle, MathExp(PriceAvgLow[i + Depth] * StDev + Mean));
  }

  FileClose(handle);

  return(Amount);
}

int GetTimePos( int SearchTime )
{
  int LeftTime, RightTime, PosTime;
  int Left, Right, Pos = 0;

  Left = 0;
  Right = ArraySize(Times) - 1;

  LeftTime = Times[Left];
  RightTime = Times[Right];

  if (SearchTime >= RightTime)
    Pos = Right;

  while ((LeftTime < SearchTime) && (SearchTime < RightTime))
  {
    Pos = (Left + Right) >> 1;
    PosTime = Times[Pos];

    if (Pos == Left)
      break;

    if (SearchTime >= PosTime)
    {
      Left = Pos;
      LeftTime = PosTime;
    }
    else // if (SearchTime < PosTime)
    {
      Right = Pos;
      RightTime = PosTime;
    }
  }

  return(Pos);
}

void SetVertLine( string Name, int Pos)
{
  Name = WHandle + Name;

  ObjectSet(Name, OBJPROP_TIME1, Pos);

  return;
}

void CreateVertLine( string Name, int Color )
{
  Name = WHandle + Name;

  ObjectCreate(Name, OBJ_VLINE, 0, 0, 0);
  ObjectSet(Name, OBJPROP_BACK, TRUE);
  ObjectSet(Name, OBJPROP_STYLE, STYLE_DASH);
  ObjectSet(Name, OBJPROP_COLOR, Color);

  return;
}

void FileToNull( string FileName )
{
  int handle = FileOpen(FileName, FILE_BIN|FILE_WRITE);

  FileClose(handle);

  return;
}

void init()
{
  string Name;
  int Pos = WindowFirstVisibleBar() - WindowBarsPerChart() + Depth;

  if (Pos < 0)
    Pos = 0;

  Shift = WindowBarsPerChart() + Pos - WindowFirstVisibleBar();

  WHandle = WindowHandle(Symbol(), Period());

  CreateVertLine("EndInterval", ColorLine);
  CreateVertLine("BeginInterval", ColorLine);

  Coord2 = Time[Pos];
  Coord1 = Time[Pos + InitInterval];

  SetVertLine("BeginInterval", Coord1);
  SetVertLine("EndInterval", Coord2);

  Coord1++;

  for (int i = 0; i < AMOUNT_OBJECT; i++)
  {
    Name = WHandle + i + "_";

    ObjectCreate(Name, OBJ_LABEL, 0, 0, 0);
    ObjectSet(Name, OBJPROP_XDISTANCE, 0);
    ObjectSet(Name, OBJPROP_YDISTANCE, (i + 1) * STEP_TEXT);

    ObjectSetText(Name, Str1[i], FONT_SIZE, "Times New Roman", ColorText1);

    Name = WHandle + i;

    ObjectCreate(Name, OBJ_LABEL, 0, 0, 0);
    ObjectSet(Name, OBJPROP_XDISTANCE, ObjXCoord[i]);
    ObjectSet(Name, OBJPROP_YDISTANCE, (i + 1) * STEP_TEXT);

  }

  StrToObjects(ColorText2);

  WindowRedraw();

  return;
}

void DeleteAllObjects()
{
  string Name;
  int i = ObjectsTotal() - 1;

  while (i >= 0)
  {
    Name = ObjectName(i);

    if (StringFind(Name, WHandle) >= 0)
      ObjectDelete(Name);

    i--;
  }

  WindowRedraw();

  return;
}

void deinit()
{
  Comment("");

  DeleteAllObjects();

  FileToNull(WHandle + "i.dat");

  return;
}

void StrToObjects( color Color )
{
  string Name;

  for (int i = 0; i < AMOUNT_OBJECT; i++)
  {
    Name = WHandle + i;

    ObjectSetText(Name, Str2[i], FONT_SIZE, "Times New Roman", Color);
  }

  WindowRedraw();

  return;
}

void start()
{
  double Corr[];
  int Pos, Begin, End;
  int Amount;
  double CorrAvg;
  bool FlagChange;
  int StartTime;
  int NewSize, Size = 1;

  while (!IsStopped())
  {
    if (GetChange2(Pause))
    {
      FlagChange = Coord2 > Times[Size - 1];

      if (FlagChange)
        Size = GetPrices(Prices, PricesHigh, PricesLow, Alpha);

      Begin = GetTimePos(Coord1);
      End = GetTimePos(Coord2);
      NewSize = End - Begin + 1;

      Comment(WindowExpertName() + ": please wait for the calculation ...");

      StartTime = GetTickCount();

      GetCorrelation(Corr, Prices, Begin, End, FlagChange);
      Amount = DataToIndicator(Corr, Pos, CorrAvg, Shablon, Size - 1 - End);

      Str2[0] = NewSize + " bars (" + TimeToStr(Coord1) + " - " + TimeToStr(Coord2) + ")";
      Str2[1] = Size + " bars (from " + TimeToStr(Times[0]) + ")";
      Str2[2] = DoubleToStr(100 * Corr[Pos], 2) + "% (" + TimeToStr(Times[Pos]) + ")";
      Str2[3] = Amount + " (" + DoubleToStr(100 * CorrAvg, 2) + "%)";
      Str2[4] = DoubleToStr((GetTickCount() - StartTime) / 1000.0, 1) + " s.";

      StrToObjects(ColorText2);

      Comment(WindowExpertName() + ": Limit = " + DoubleToStr(Limit, 2) + ", MinStep = " + DoubleToStr(MinStep, 2));

      AddTick();
    }

    Sleep(PAUSE);
  }

  return;
}

#import "user32.dll"
  int PostMessageA( int hWnd, int Msg, int wParam, int lParam );
  int RegisterWindowMessageA( string lpString );
#import

void AddTick()
{
  if (!IsDllsAllowed())
    return;

  int hwnd = WindowHandle(Symbol(), Period());
  int MT4InternalMsg = RegisterWindowMessageA("MetaTrader4_Internal_Message");

  PostMessageA(hwnd, MT4InternalMsg, 2, 1);

  return;
}