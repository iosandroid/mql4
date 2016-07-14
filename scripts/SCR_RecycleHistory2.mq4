#property show_inputs

#define MAX_AMOUNTSYMBOLS 15
#define MAX_POINTS 100000

extern datetime StartTime = D'2016.06.27';

string SymbolsStr;
int Depth, Iterations, Method;
bool Correlation;

string Symbols[MAX_AMOUNTSYMBOLS];
double BaseMatrix[][MAX_POINTS], MOMatrix[][MAX_POINTS];
double CvarMatrix[][MAX_AMOUNTSYMBOLS];
double Means[], SVector[], Divs[];
int Times[MAX_POINTS];
int AmountSymbols, MatrixRows, Time0;
int CurrPos;

int AmountSymbols2;
int AmountVariants, Variants[];

string UName;

double Matrix[][MAX_AMOUNTSYMBOLS], VectorTmp[];

void GetConfig( string FileName )
{
  int handle = FileOpen(FileName, FILE_CSV|FILE_READ);

  SymbolsStr = FileReadString(handle);
  Correlation = (FileReadNumber(handle) == 1);
  Depth = FileReadNumber(handle);
  Method = FileReadNumber(handle);
  Iterations = FileReadNumber(handle);

  FileClose(handle);

  return;
}

string StrDelSpaces( string Str )
{
  int Pos, Length;

  Str = StringTrimLeft(Str);
  Str = StringTrimRight(Str);

  Length = StringLen(Str) - 1;
  Pos = 1;

  while (Pos < Length)
    if (StringGetChar(Str, Pos) == ' ')
    {
      Str = StringSubstr(Str, 0, Pos) + StringSubstr(Str, Pos + 1, 0);
      Length--;
    }
    else
      Pos++;

  return(Str);
}

int StrToStringS( string Str, string Razdelitel, string &Output[] )
{
  int Pos, LengthSh;
  int Count = 0;

  Str = StrDelSpaces(Str);
  Razdelitel = StrDelSpaces(Razdelitel);

  LengthSh = StringLen(Razdelitel);

  while (TRUE)
  {
    Pos = StringFind(Str, Razdelitel);
    Output[Count] = StringSubstr(Str, 0, Pos);
    Count++;

    if (Pos == -1)
      break;

    Pos += LengthSh;
    Str = StringSubstr(Str, Pos);
  }

  return(Count);
}

datetime GetStartTime( datetime StartTime )
{
  datetime Tmp;
  int Pos;

  for (int i = 0; i < AmountSymbols; i++)
  {
    Pos = iBarShift(Symbols[i], Period(), StartTime);

    if (Pos == 0)
      return(Time0);

    Tmp = iTime(Symbols[i], Period(), Pos);

    if (Tmp < StartTime)
      Tmp = iTime(Symbols[i], Period(), Pos - 1);

    StartTime = Tmp;
  }

  for (i = 0; i < AmountSymbols; i++)
    if (StartTime > iTime(Symbols[i], Period(), 0))
      return(Time0);

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
  static int Pos[MAX_AMOUNTSYMBOLS];
  int i, MinTime, Tmp = -1;

  for (i = 0; i < AmountSymbols; i++)
  {
    Pos[i] = iBarShift(Symbols[i], Period(), CurrTime) - 1;

    if (Pos[i] >= 0)
      Tmp = i;
  }

  if (Tmp < 0)
    return(Time0);

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
  int i, CurrTime = StartTime;

  MatrixRows = 0;

  while (CurrTime < Time0)
  {
    for (i = 0; i < AmountSymbols; i++)
      BaseMatrix[i][MatrixRows] = 1000 * MathLog(GetPrice(Symbols[i], CurrTime));

    Times[MatrixRows] = CurrTime;

    MatrixRows++;

    CurrTime = GetNextTime(CurrTime);
  }

  return;
}

void GetMeans( int Pos, int Len)
{
  int i, j;
  double Sum;

  for (i = 0; i < AmountSymbols; i++)
  {
    Sum = 0;

    for (j = Pos; j > Pos - Len; j--)
      Sum += BaseMatrix[i][j];

    Print(Len);
    Means[i] = Sum / Len;
    
  }

  return;
}

void GetMOMatrix( int Pos, int Len)
{
  int i, j;
  double Sum;

  for (i = 0; i < AmountSymbols; i++)
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

  for (i = 0; i < AmountSymbols; i++)
  {
    Cvar = 0;

    for (k = Pos; k > Pos - Len; k--)
      Cvar += MOMatrix[i][k] * MOMatrix[i][k];

    Cvar /= Len;
    Divs[i] = Cvar;
    CvarMatrix[i][i] = Cvar;

    for (j = i + 1; j < AmountSymbols; j++)
    {
      Cvar = 0;

     for (k = Pos; k > Pos - Len; k--)
        Cvar += MOMatrix[i][k] * MOMatrix[j][k];

      CvarMatrix[i][j] = Cvar / Len;
    }
  }
  return;
}

bool Init()
{
  UName = "hwnd" + WindowHandle(Symbol(), Period());

  if (!GlobalVariableCheck(UName))
    return(FALSE);

  GetConfig(UName + ".ini");

  AmountSymbols = StrToStringS(SymbolsStr, ",", Symbols);
  AmountSymbols2 = AmountSymbols * MAX_AMOUNTSYMBOLS;

  ArrayResize(Symbols, AmountSymbols);
  ArrayResize(BaseMatrix, AmountSymbols);
  ArrayResize(MOMatrix, AmountSymbols);
  ArrayResize(CvarMatrix, AmountSymbols);
  ArrayResize(Means, AmountSymbols);
  ArrayResize(SVector, AmountSymbols);
  ArrayResize(Divs, AmountSymbols);

  ArrayResize(Matrix, AmountSymbols);
  ArrayResize(VectorTmp, AmountSymbols);

  if (Method == 4)
    AmountVariants = GetVariants(Variants, AmountSymbols);

  Time0 = GlobalVariableGet(UName + "LastTime");
  StartTime = GetStartTime(StartTime);

  CurrPos = Depth;

  Comment(WindowExpertName() + ":\nGetting history data... (StartTime = " + TimeToStr(StartTime) + ")");

  GetBaseMatrix();

  GetCvarMatrix(CurrPos - 1, Depth);

  return(TRUE);
}

void GetNextMeans( int Pos, int Len )
{
  int Pos2 = Pos - Len;

  for (int i = 0; i < AmountSymbols; i++)
  {
    SVector[i] = (BaseMatrix[i][Pos2] - BaseMatrix[i][Pos]) / Len;
    Means[i] -= SVector[i];
  }

  return;
}

void GetNextCvarMatrix( int Pos, int Len )
{
  int i, j;
  int Pos2 = Pos - Len;
  double Tmp1, Tmp2, Tmp3;

  GetNextMeans(Pos, Len);

  for (i = 0; i < AmountSymbols; i++)
  {
    Tmp1 = SVector[i];
    Tmp2 = BaseMatrix[i][Pos] - Means[i];
    Tmp3 = BaseMatrix[i][Pos2] - Means[i];

    CvarMatrix[i][i] += Tmp1 * Tmp1 + (Tmp2 * Tmp2 - Tmp3 * Tmp3) / Len;

    if (CvarMatrix[i][i] < 0)
    {
      CvarMatrix[i][i] = 0;
      Divs[i] = 0;
    }
    else
      Divs[i] = CvarMatrix[i][i];

    for (j = i + 1; j < AmountSymbols; j++)
      CvarMatrix[i][j] += Tmp1 * SVector[j] + (Tmp2 * (BaseMatrix[j][Pos] - Means[j]) - Tmp3 * (BaseMatrix[j][Pos2] - Means[j])) / Len;
  }

  return;
}

void InvertMatrix( double& Matrix[][] )
{
  static int rn[];
  static double str[], strm[];
  int j,k;
  int jved;
  double aved, Tmp;

  ArrayResize(rn, AmountSymbols);
  ArrayResize(str, AmountSymbols);
  ArrayResize(strm, AmountSymbols);

  for (j = 0; j < AmountSymbols; j++)
    rn[j] = j;

  for (int i = 0; i < AmountSymbols; i++)
  {
    aved = -1;

    for (j = 0; j < AmountSymbols; j++)
      if (rn[j] != -1)
      {
        Tmp = MathAbs(Matrix[j][j]);

        if (Tmp > aved)
        {
           aved = Tmp;
           jved = j;
        }
      }

    rn[jved] = -1;

    for (j = 0; j < jved; j++)
    {
      str[j] = Matrix[j][jved];
      strm[j] = str[j] / aved;
    }

    for (j = jved + 1; j < AmountSymbols; j++)
    {
      str[j] = Matrix[jved][j];
      strm[j] = str[j] / aved;
    }

    for (j = 0; j < AmountSymbols; j++)
      for (k = j; k < AmountSymbols; k++)
        Matrix[j][k] -= strm[j] * str[k];

    for (j = 0; j < jved; j++)
      Matrix[j][jved] = strm[j];

    for (j = jved + 1; j < AmountSymbols; j++)
      Matrix[jved][j] = strm[j];

    Matrix[jved][jved] = -1 / aved;
  }

  return;
}

bool CheckVectorChange( double& V[], double& VChange[] )
{
  int i;
  bool Res;
  double Sum1 = 0, Sum2 = 0;

  for (i = 0; i < AmountSymbols; i++)
  {
    Sum1 += MathAbs(V[i] - VChange[i]);
    Sum2 += MathAbs(V[i] + VChange[i]);
  }

  Res = (Sum1 > Sum2);

  if (Res)
    for (i = 0; i < AmountSymbols; i++)
      VChange[i] = -VChange[i];

  return(Res);
}

void GetOptimalVector1( double& Vector[], int Iterations )
{
  int i, j, k;
  double Tmp, Max = 0;

  while (Iterations > 0)
  {
    for (i = 0; i < AmountSymbols; i++)
      for (j = AmountSymbols - 1; j >= i; j--)
      {
        Tmp = 0;
        k = 0;

        while (k < i)
        {
          Tmp += Matrix[k][i] * Matrix[k][j];

          k++;
        }

        while (k < j)
        {
          Tmp += Matrix[i][k] * Matrix[k][j];

          k++;
        }

        while (k < AmountSymbols)
        {
          Tmp += Matrix[i][k] * Matrix[j][k];

          k++;
        }

        Matrix[j][i] = Tmp;
      }

    for (i = 0; i < AmountSymbols; i++)
      for (j = i + 1; j < AmountSymbols; j++)
        Matrix[i][j] = Matrix[j][i];

    Iterations--;
  }

  for (i = 0; i < AmountSymbols; i++)
  {
    Tmp = 0;

    for (j = 0; j < AmountSymbols; j++)
      if (Matrix[i][j] < 0)
        Tmp -= Matrix[i][j];
      else
        Tmp += Matrix[i][j];

    if (Tmp > Max)
    {
       Max = Tmp;
       k = i;
    }
  }

  ArrayCopy(VectorTmp, Vector);

  for (i = 0; i < AmountSymbols; i++)
    Vector[i] = Matrix[k][i] / Max;

  CheckVectorChange(VectorTmp, Vector);

  return;
}

double GetOptimalVector2( double& Vector[] )
{
  int i, j;
  double Tmp, Max = 0, StDev = 0;

  for (i = 0; i < AmountSymbols; i++)
  {
    Tmp = 0;
    j = 0;

    while (j < i)
    {
      Tmp -= Matrix[j][i];

      j++;
    }

    while (j < AmountSymbols)
    {
      Tmp -= Matrix[i][j];

      j++;
    }

    VectorTmp[i] = Tmp;
    StDev += Tmp;

    if (Tmp < 0)
      Max -= Tmp;
    else
      Max += Tmp;
  }

  for (i = 0; i < AmountSymbols; i++)
    VectorTmp[i] /= Max;

  CheckVectorChange(Vector, VectorTmp);

  ArrayCopy(Vector, VectorTmp);

  StDev = MathSqrt(StDev) / Max;

  return(StDev);
}

double GetOptimalVector3( double& Vector[] )
{
  int i, j;
  double Tmp, Max = 0, StDev;
  static bool Flag[];

  ArrayResize(Flag, AmountSymbols);

  for (i = 0; i < AmountSymbols; i++)
  {
    Tmp = 0;
    j = 0;

    Flag[i] = FALSE;

    while (j < i)
    {
      Tmp -= Matrix[j][i];

      j++;
    }

    while (j < AmountSymbols)
    {
      Tmp -= Matrix[i][j];

      j++;
    }

    VectorTmp[i] = Tmp / 2;
  }

  i = 0;

  while (i < AmountSymbols)
    if (VectorTmp[i] < 0)
    {
      Flag[i] = !Flag[i];
      VectorTmp[i] = -VectorTmp[i];

      j = 0;

      while (j < i)
      {
        if (Flag[j] == Flag[i])
          VectorTmp[j] -= Matrix[j][i];
        else
          VectorTmp[j] += Matrix[j][i];

        j++;
      }

      while (j < AmountSymbols)
      {
        if (Flag[j] == Flag[i])
          VectorTmp[j] -= Matrix[i][j];
        else
          VectorTmp[j] += Matrix[i][j];

        j++;
      }

      i = 0;
    }
    else
      i++;

  for (i = 0; i < AmountSymbols; i++)
    Max += VectorTmp[i];

  for (i = 0; i < AmountSymbols; i++)
    if (Flag[i])
      VectorTmp[i] /= -Max;
    else
      VectorTmp[i] /= Max;

  CheckVectorChange(Vector, VectorTmp);

  ArrayCopy(Vector, VectorTmp);

  StDev = 1 / MathSqrt(Max + Max);

  return(StDev);
}

int GetVariants( int& Variants[], int Amount )
{
  int i, j;
  int Pos = 1, Step = 2;
  int AmountVariants = MathPow(2, Amount - 1) - 1;

  ArrayResize(Variants, AmountVariants + 1);

  for (i = 0; i < Amount - 1; i++)
  {
    for (j = Pos - 1; j < AmountVariants; j += Step)
      Variants[j] = i;

    Pos <<= 1;
    Step <<= 1;
  }

  Variants[AmountVariants] = Amount - 2;

  return(AmountVariants + 1);
}

double GetOptimalVector4( double& Vector[] )
{
  int i, j;
  double Tmp, Max = 0, StDev;
  bool FlagPositive;
  static bool Flag[], BestFlag[];
  static double BestVector[];

  ArrayResize(Flag, AmountSymbols);
  ArrayResize(BestFlag, AmountSymbols);
  ArrayResize(BestVector, AmountSymbols);

  for (i = 0; i < AmountSymbols; i++)
  {
    Tmp = 0;
    j = 0;

    Flag[i] = FALSE;

    while (j < i)
    {
      Tmp -= Matrix[j][i];

      j++;
    }

    while (j < AmountSymbols)
    {
      Tmp -= Matrix[i][j];

      j++;
    }

    VectorTmp[i] = Tmp / 2;
  }

  for (int k = 0; k < AmountVariants; k++)
  {
    i = Variants[k];
    FlagPositive = TRUE;
    StDev = 0;

    Flag[i] = !Flag[i];
    VectorTmp[i] = -VectorTmp[i];

    j = 0;

    while (j < i)
    {
      if (Flag[j] == Flag[i])
        VectorTmp[j] -= Matrix[j][i];
      else
        VectorTmp[j] += Matrix[j][i];

      if (FlagPositive)
      {
        if (VectorTmp[j] >= 0)
          StDev += VectorTmp[j];
        else
          FlagPositive = FALSE;
      }

      j++;
    }

    while (j < AmountSymbols)
    {
      if (Flag[j] == Flag[i])
        VectorTmp[j] -= Matrix[i][j];
      else
        VectorTmp[j] += Matrix[i][j];

      if (FlagPositive)
      {
        if (VectorTmp[j] >= 0)
          StDev += VectorTmp[j];
        else
          FlagPositive = FALSE;
      }

      j++;
    }

    if (FlagPositive)
      if (StDev > Max)
      {
        Max = StDev;

        ArrayCopy(BestVector, VectorTmp);
        ArrayCopy(BestFlag, Flag);
      }
  }

  for (i = 0; i < AmountSymbols; i++)
    if (BestFlag[i])
      BestVector[i] /= -Max;
    else
      BestVector[i] /= Max;

  CheckVectorChange(Vector, BestVector);

  ArrayCopy(Vector, BestVector);

  StDev = 1 / MathSqrt(Max + Max);

  return(StDev);
}

double GetOptimalVector( double& Vector[], int Method, bool Correlation )
{
  int i, j;
  double Tmp, Tmp2, StDev;

  ArrayCopy(Matrix, CvarMatrix, 0, 0, AmountSymbols2);

  if (Correlation)
  {
    for (i = 0; i < AmountSymbols; i++)
      Divs[i] = MathSqrt(Divs[i]);

    for (i = 0; i < AmountSymbols; i++)
    {
      Matrix[i][i] = 1;
      Tmp = Divs[i];

      if (Tmp != 0)
        for (j = i + 1; j < AmountSymbols; j++)
        {
          Tmp2 = Tmp * Divs[j]; // if Divs[] != 0, then Divs[] * Divs[] != 0, because MathSqrt.

          if (Tmp2 != 0)
            Matrix[i][j] /= Tmp2;
          else
            Matrix[i][j] = 0;
        }
      else
        for (j = i + 1; j < AmountSymbols; j++)
          Matrix[i][j] = 0;
    }
  }

  InvertMatrix(Matrix);

  switch (Method)
  {
    case 1:
      GetOptimalVector1(Vector, Iterations);
      StDev = GetDivergence(CurrPos, Depth, Vector, Correlation);
      break;
    case 2:
      StDev = GetOptimalVector2(Vector);
      break;
    case 3:
      StDev = GetOptimalVector3(Vector);
      break;
    case 4:
      StDev = GetOptimalVector4(Vector);
      break;
  }

  return(StDev);
}

double GetRecycle( int Pos, int Len, double& Vector[], bool Correlation )
{
  int i;
  double Recycle = 0;

  if (Correlation)
  {
    for (i = 0; i < AmountSymbols; i++)
      if (Divs[i] != 0)
        Recycle += (BaseMatrix[i][Pos] - Means[i]) * Vector[i] / Divs[i]; // Divs == StdDev
  }
  else
    for (i = 0; i < AmountSymbols; i++)
      Recycle += (BaseMatrix[i][Pos] - Means[i]) * Vector[i];

  return(Recycle);
}

double GetDivergence( int Pos, int Len, double& Vector[], bool Correlation )
{
  int i, j;
  double Sum, Div = 0, Tmp = 0;

  if (Correlation)
  {
    for (i = 0; i < AmountSymbols; i++)
      if (Divs[i] != 0)
      {
        VectorTmp[i] = Vector[i] / Divs[i];
        Tmp -= Means[i] * VectorTmp[i];
      }

    for (i = Pos; i > Pos - Len; i--)
    {
      Sum = Tmp;

      for (j = 0; j < AmountSymbols; j++)
        if (Divs[j] != 0)
          Sum += BaseMatrix[j][i] * Vector[j] / Divs[j]; // Divs == StdDev

      Div += Sum * Sum;
    }
  }
  else
  {
    for (i = 0; i < AmountSymbols; i++)
      Tmp -= Means[i] * Vector[i];

    for (i = Pos; i > Pos - Len; i--)
    {
      Sum = Tmp;

      for (j = 0; j < AmountSymbols; j++)
        Sum += BaseMatrix[j][i] * Vector[j];

      Div += Sum * Sum;
    }
  }

  Div /= Len;

  return(MathSqrt(Div));
}

void deinit()
{
  Comment("");

  GlobalVariableSet(UName + "Done", 0);

  AddTick();

  return;
}

void SetComment( int TimeInterval )
{
  string Str = WindowExpertName() + ":\n";

  Str = Str + "Depth = " + Depth + " bars, AmountSymbols = " + AmountSymbols + "\n";
  Str = Str + "Ready: " + DoubleToStr(100.0 * (CurrPos - Depth) / (MatrixRows - Depth), 1) + "%";
  Str = Str + " (" + TimeToStr(Times[CurrPos]) + ")\n";

  if (TimeInterval != 0)
    Str = Str + "Performance = "  + DoubleToStr((CurrPos - Depth) * 1000 / TimeInterval, 0) + " bars/sec.\n";

  Str = Str + "Elapsed time: " + TimeToStr(TimeInterval / 1000, TIME_SECONDS) + "\n";
  Str = Str + "Remaining time: " + TimeToStr(1.0 * (MatrixRows - CurrPos) * TimeInterval / (1000 * (CurrPos - Depth)), TIME_SECONDS);

  Comment(Str);

  return;
}

void start()
{
  int Start, handle;
  int PrevTime, CurrentTime;
  double Div, Recycle, V[];

  if (!Init())
    return;

  ArrayResize(V, AmountSymbols);
  handle = FileOpen(UName + ".dat", FILE_BIN|FILE_WRITE);

  Start = GetTickCount();
  PrevTime = Start;

  while (CurrPos < MatrixRows)
  {
    if (!GlobalVariableCheck(UName))
      break;

    GetNextCvarMatrix(CurrPos, Depth);
//    GetCvarMatrix(CurrPos, Depth);
    Div = GetOptimalVector(V, Method, Correlation);
    Recycle = GetRecycle(CurrPos, Depth, V, Correlation);

    FileWriteInteger(handle, Times[CurrPos]);
    FileWriteDouble(handle, Recycle);
    FileWriteDouble(handle, Div);

    FileWriteArray(handle, V, 0, AmountSymbols);

    CurrPos++;

    CurrentTime = GetTickCount();

    if ((CurrentTime - PrevTime > 1000) || (CurrentTime - PrevTime < -1000))
    {
      PrevTime = CurrentTime;

      SetComment(CurrentTime - Start);
    }

    if (IsStopped())
      break;
  }

  FileClose(handle);

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

