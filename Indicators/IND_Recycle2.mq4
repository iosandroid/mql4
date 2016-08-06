//https://www.mql5.com/ru/code/9908
//https://www.mql5.com/ru/code/10096
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_color1 Red
#property indicator_width1 2
#property indicator_color2 Blue
#property indicator_width2 1
#property indicator_color3 Blue
#property indicator_width3 1

#define MAX_AMOUNTSYMBOLS 15
#define MAX_POINTS 100000

//extern string SymbolsStr = "#AUS200, #ESX50, #SPXm, #FCHI, #GDAXIm, #NDXm";
extern string SymbolsStr = "EURUSD, GBPJPY, NZDUSD, GBPUSD, EURCHF, AUDCHF";
extern bool SymbolKoef = FALSE;
extern bool Correlation = FALSE;
extern int Depth = 1440;
extern int Method = 4;
extern int Height = 300;
extern int BarStep = 36;
extern color ColorText = Gray;
extern color ColorPlusBar = Yellow;
extern color ColorMinusBar = Magenta;
extern color ColorDigits = Blue;
extern color ColorAxis = Green;
extern color ColorArrow = Blue;
extern color ColorLine = Blue;
int Iterations = 6; // for Method = 1

string UName, IndName;
int SymbolPos;
double Buffer[], Buffer2[], Buffer3[];

string Symbols[MAX_AMOUNTSYMBOLS];
double BaseMatrix[][MAX_POINTS], MOMatrix[][MAX_POINTS], Vectors[][MAX_POINTS], Divers[MAX_POINTS], Recycles[MAX_POINTS];
double CvarMatrix[][MAX_AMOUNTSYMBOLS];
double Means[], Divs[];
int Times[MAX_POINTS];
int AmountSymbols, CurrTime, MatrixRows, CurrPos;
double V[], VectorTmp[];
int AmountVariants, Variants[];

string FontName = "Arial";

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

int BooleanToInteger( bool Value )
{
  if (Value)
    return(1);

  return(0);
}

bool RealSymbol( string Symb )
{
  return(MarketInfo(Symb, MODE_BID) != 0);
}

void FilterSymbols()
{
  int i, j;

  for (i = 0; i < AmountSymbols; i++)
    if (!RealSymbol(Symbols[i]))
    {
      for (j = i; j < AmountSymbols - 1; j++)
        Symbols[j] = Symbols[j + 1];

      AmountSymbols--;
    }

  return;
}

void SaveConfig( string FileName )
{
  string Str = Symbols[0];
  int handle = FileOpen(FileName, FILE_CSV|FILE_WRITE);

  for (int i = 1; i < AmountSymbols; i++)
    Str = Str + ", " + Symbols[i];

  FileWrite(handle, Str);
  FileWrite(handle, BooleanToInteger(Correlation));
  FileWrite(handle, Depth);
  FileWrite(handle, Method);
  FileWrite(handle, Iterations);
  FileWrite(handle, Height);

  FileClose(handle);

  return;
}

datetime GetStartTime( int Pos )
{
  datetime Tmp, StartTime;
  int i, PosAddon;

  PosAddon = iBarShift(Symbols[0], Period(), Time[0]);
  StartTime = iTime(Symbols[0], Period(), Pos + PosAddon);

  for (i = 1; i < AmountSymbols; i++)
  {
    PosAddon = iBarShift(Symbols[i], Period(), Time[0]);
    Tmp = iTime(Symbols[i], Period(), Pos + PosAddon);

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
  static int Pos[MAX_AMOUNTSYMBOLS];
  int i, MinTime, Tmp = -1;

  for (i = 0; i < AmountSymbols; i++)
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

    for (i = 0; i < AmountSymbols; i++)
      BaseMatrix[i][MatrixRows] = 1000 * MathLog(GetPrice(Symbols[i], CurrTime));

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

  for (i = 0; i < AmountSymbols; i++)
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

void FileToNull( string FileName )
{
  int handle = FileOpen(FileName, FILE_BIN|FILE_WRITE);

  FileClose(handle);

  return;
}

void SetIndName()
{
  if (SymbolPos < AmountSymbols)
  {
    if (Correlation)
      IndName = "Correlation Absolute Koef";
    else
      IndName = "Recycle Absolute Koef";
  }
  else if (Correlation)
    IndName = "Correlation Koefs";
  else
    IndName = "Recycle Koefs";

  IndicatorShortName(IndName);

  return;
}

int GetSymbolPos( string Symb )
{
  int Pos = 0;

  while (Pos < AmountSymbols)
  {
    if (Symb == Symbols[Pos])
      break;

    Pos++;
  }

  return(Pos);
}

void init()
{
  UName = "hwnd" + WindowHandle(Symbol(), Period());

  FileToNull(UName + "i.dat");

  IndicatorDigits(8);

  SetIndexStyle(0, DRAW_LINE, DRAW_LINE);
  SetIndexBuffer(0, Buffer);

  SetIndexStyle(1, DRAW_LINE, DRAW_LINE);
  SetIndexBuffer(1, Buffer2);

  SetIndexStyle(2, DRAW_LINE, DRAW_LINE);
  SetIndexBuffer(2, Buffer3);

  AmountSymbols = StrToStringS(SymbolsStr, ",", Symbols);
  FilterSymbols();

  if (SymbolKoef)
    SymbolPos = GetSymbolPos(Symbol());
  else
    SymbolPos = AmountSymbols;

  SetIndName();

  SaveConfig(UName + ".ini");

  GlobalVariableSet(UName + "SymbolPos", SymbolPos);
  GlobalVariableSet(UName + "LastTime", Time[0]);
  GlobalVariableSet(UName, 0);

  ArrayResize(Symbols, AmountSymbols);
  ArrayResize(BaseMatrix, AmountSymbols);
  ArrayResize(MOMatrix, AmountSymbols);
  ArrayResize(CvarMatrix, AmountSymbols);
  ArrayResize(Means, AmountSymbols);
  ArrayResize(Divs, AmountSymbols);
  ArrayResize(Vectors, AmountSymbols);
  ArrayResize(V, AmountSymbols);
  ArrayResize(VectorTmp, AmountSymbols);

  if (Method == 4)
    AmountVariants = GetVariants(Variants, AmountSymbols);

  CurrTime = GetStartTime(Depth + 1);

  MatrixRows = 0;

  CurrPos = Depth - 1;

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
          Tmp += CvarMatrix[k][i] * CvarMatrix[k][j];

          k++;
        }

        while (k < j)
        {
          Tmp += CvarMatrix[i][k] * CvarMatrix[k][j];

          k++;
        }

        while (k < AmountSymbols)
        {
          Tmp += CvarMatrix[i][k] * CvarMatrix[j][k];

          k++;
        }

        CvarMatrix[j][i] = Tmp;
      }

    for (i = 0; i < AmountSymbols; i++)
      for (j = i + 1; j < AmountSymbols; j++)
        CvarMatrix[i][j] = CvarMatrix[j][i];

    Iterations--;
  }

  for (i = 0; i < AmountSymbols; i++)
  {
    Tmp = 0;

    for (j = 0; j < AmountSymbols; j++)
    {
      if (CvarMatrix[i][j] < 0)
      {
        Tmp -= CvarMatrix[i][j];
      }
      else
      {
        Tmp += CvarMatrix[i][j];
      }
    }

    if (Tmp > Max)
    {
      Max = Tmp;
      k = i;
    }
  }

  ArrayCopy(VectorTmp, Vector);

  for (i = 0; i < AmountSymbols; i++)
    Vector[i] = CvarMatrix[k][i] / Max;

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
      Tmp -= CvarMatrix[j][i];

      j++;
    }

    while (j < AmountSymbols)
    {
      Tmp -= CvarMatrix[i][j];

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
      Tmp -= CvarMatrix[j][i];

      j++;
    }

    while (j < AmountSymbols)
    {
      Tmp -= CvarMatrix[i][j];

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
          VectorTmp[j] -= CvarMatrix[j][i];
        else
          VectorTmp[j] += CvarMatrix[j][i];

        j++;
      }

      while (j < AmountSymbols)
      {
        if (Flag[j] == Flag[i])
          VectorTmp[j] -= CvarMatrix[i][j];
        else
          VectorTmp[j] += CvarMatrix[i][j];

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
      Tmp -= CvarMatrix[j][i];

      j++;
    }

    while (j < AmountSymbols)
    {
      Tmp -= CvarMatrix[i][j];

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
        VectorTmp[j] -= CvarMatrix[j][i];
      else
        VectorTmp[j] += CvarMatrix[j][i];

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
        VectorTmp[j] -= CvarMatrix[i][j];
      else
        VectorTmp[j] += CvarMatrix[i][j];

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

  if (Correlation)
  {
    for (i = 0; i < AmountSymbols; i++)
      Divs[i] = MathSqrt(Divs[i]);

    for (i = 0; i < AmountSymbols; i++)
    {
      CvarMatrix[i][i] = 1;
      Tmp = Divs[i];

      if (Tmp != 0)
        for (j = i + 1; j < AmountSymbols; j++)
        {
          Tmp2 = Tmp * Divs[j]; // if Divs[] != 0, then Divs[] * Divs[] != 0, because MathSqrt.

          if (Tmp2!= 0)
            CvarMatrix[i][j] /= Tmp2;
          else
            CvarMatrix[i][j] = 0;
        }
      else
        for (j = i + 1; j < AmountSymbols; j++)
          CvarMatrix[i][j] = 0;
    }
  }

  InvertMatrix(CvarMatrix);
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
        Recycle += MOMatrix[i][Pos] * Vector[i] / Divs[i]; // Divs == StdDev
  }
  else
    for (i = 0; i < AmountSymbols; i++)
      Recycle += MOMatrix[i][Pos] * Vector[i];

  return(Recycle);
}

double GetDivergence( int Pos, int Len, double& Vector[], bool Correlation )
{
  int i, j;
  double Sum, Div = 0;

  if (Correlation)
  {
    ArrayCopy(VectorTmp, Vector, 0, 0, AmountSymbols);

    for (i = 0; i < AmountSymbols; i++)
      if (Divs[i] != 0)
        VectorTmp[i] /= Divs[i]; // Divs == StdDev

    for (i = Pos; i > Pos - Len; i--)
    {
      Sum = 0;

      for (j = 0; j < AmountSymbols; j++)
        if (Divs[j] != 0)
          Sum += MOMatrix[j][i] * VectorTmp[j];

      Div += Sum * Sum;
    }
  }
  else
    for (i = Pos; i > Pos - Len; i--)
    {
      Sum = 0;

      for (j = 0; j < AmountSymbols; j++)
        Sum += MOMatrix[j][i] * Vector[j];

      Div += Sum * Sum;
    }

  Div /= Len;

  return(MathSqrt(Div));
}

void deinit()
{
  GlobalVariableDel(UName);
  GlobalVariableDel(UName + "LastTime");
  GlobalVariableDel(UName + "SymbolPos");

  ObjectDelete("BeginInterval");
  ObjectDelete("EndInterval");

  FileToNull(UName + ".ini");
  FileToNull(UName + ".dat");
  FileToNull(UName + "i.dat");

  return;
}

void GetSaveData( string FileNameIn, string FileNameOut )
{
  int i, time, Pos, Pos2;
  double Div, Recycle;
  bool FlagReverse;

  int handleIn = FileOpen(FileNameIn, FILE_BIN|FILE_READ);
  int handleOut = FileOpen(FileNameOut, FILE_BIN|FILE_WRITE);

  while (FileTell(handleIn) < FileSize(handleIn))
  {
    time = FileReadInteger(handleIn);
    FileWriteInteger(handleOut, time);

    Recycle = FileReadDouble(handleIn);
    FileWriteDouble(handleOut, Recycle);

    Div = FileReadDouble(handleIn);
    FileWriteDouble(handleOut, Div);

    FileReadArray(handleIn, V, 0, AmountSymbols);
    FileWriteArray(handleOut, V, 0, AmountSymbols);

    Pos = iBarShift(Symbol(), Period(), time);

    Buffer[Pos] = iIF(SymbolPos < AmountSymbols, MathAbs(V[SymbolPos]), Recycle);
    Buffer2[Pos] = iIF(SymbolPos < AmountSymbols, MathAbs(V[SymbolPos]), Div);
    Buffer3[Pos] = iIF(SymbolPos < AmountSymbols, MathAbs(V[SymbolPos]), -Div);
  }

  FileClose(handleIn);

  Pos = GetTimePos(time) + 1;

  if (Pos < MatrixRows)
  {
    for (i = 0; i < AmountSymbols; i++)
      VectorTmp[i] = Vectors[i][Pos];

    FlagReverse = CheckVectorChange(V, VectorTmp);
  }

  while (Pos < MatrixRows)
  {
    if (FlagReverse)
    {
      Recycles[Pos] = -Recycles[Pos];

      for (i = 0; i < AmountSymbols; i++)
        Vectors[i][Pos] = -Vectors[i][Pos];
    }

    time = Times[Pos];
    Div = Divers[Pos];
    Recycle = Recycles[Pos];

    Pos2 = iBarShift(Symbol(), Period(), time);

    Buffer[Pos2] = iIF(SymbolPos < AmountSymbols, MathAbs(Vectors[SymbolPos][Pos]), Recycle);
    Buffer2[Pos2] = iIF(SymbolPos < AmountSymbols, MathAbs(Vectors[SymbolPos][Pos]), Div);
    Buffer3[Pos2] = iIF(SymbolPos < AmountSymbols, MathAbs(Vectors[SymbolPos][Pos]), -Div);

    FileWriteInteger(handleOut, time);
    FileWriteDouble(handleOut, Recycle);
    FileWriteDouble(handleOut, Div);

    for (i = 0; i < AmountSymbols; i++)
      FileWriteDouble(handleOut, Vectors[i][Pos]);

    if (Pos == MatrixRows -1)
      for (i = 0; i < AmountSymbols; i++)
        V[i] = Vectors[i][Pos];

    Pos++;
  }

  FileClose(handleOut);

  return;
}

void HideObject( string Name, bool Hide )
{
  if (Hide)
   ObjectSet(Name, OBJPROP_TIMEFRAMES, EMPTY);
  else
   ObjectSet(Name, OBJPROP_TIMEFRAMES, NULL);

 return;
}

void CreateObject( string Name, string Value, int FontSize, int Xcoord, int Ycoord, int Angle, bool Hide, bool Back, int Color )
{
  ObjectCreate(Name, OBJ_LABEL, WindowFind(IndName), 0, 0);
  HideObject(Name, Hide);
  ObjectSet(Name, OBJPROP_ANGLE, Angle);
  ObjectSet(Name, OBJPROP_XDISTANCE, Xcoord);
  ObjectSet(Name, OBJPROP_YDISTANCE, Ycoord);
  ObjectSet(Name, OBJPROP_BACK, Back);
  ObjectSetText(Name, Value, FontSize, FontName, Color);

  return;
}

void CreateObjectBar( string Name, int Xcoord, int Ycoord )
{
  int i, Avg = Height / 2;
  string Tmp;

  CreateObject(Name, Name, 10, Xcoord - 15, Ycoord + 10 + StringLen(Name) * 5, 90, FALSE, FALSE, ColorText);
  CreateObject(Name + "Plus", "+0.0000", 8, Xcoord - 2, Ycoord, 90, TRUE, FALSE, ColorDigits);
  CreateObject(Name + "Minus", "-0.000", 8, Xcoord + 11, Ycoord + 27, -90, TRUE, FALSE, ColorDigits);

  Ycoord -= 5 + Avg;

  for (i = 0; i <= Height; i++)
  {
    Tmp = Name + i;

    if (i > Avg)
      CreateObject(Tmp, "_", 12, Xcoord, Ycoord + i, 0, TRUE, TRUE, ColorMinusBar);
    else if (i < Avg)
      CreateObject(Tmp, "_", 12, Xcoord, Ycoord + i, 0, TRUE, TRUE, ColorPlusBar);
    else
      CreateObject(Tmp, "_", 12, Xcoord, Ycoord + i, 0, TRUE, TRUE, ColorAxis);
  }

  return;
}

void CreateVertLine( string Name, int Color )
{
  ObjectCreate(Name, OBJ_VLINE, 0, 0, 0);
  ObjectSet(Name, OBJPROP_BACK, TRUE);
  ObjectSet(Name, OBJPROP_STYLE, STYLE_DASH);
  ObjectSet(Name, OBJPROP_COLOR, ColorLine);

  return;
}

void CreateBars( int Xcoord, int Ycoord, int XStep )
{
  int i, Avg = Height / 2;
  string Tmp = "";
  string Methods[4] = {"Method = 1 (Condition: Sum(Coef^2) = 1)", "Method = 2 (Condition: Sum(Coef) = 1)",
                       "Method = 3 (Condition: Sum(|Coef|) = 1 (not BEST))", "Method = 4 (Condition: Sum(|Coef|) = 1)"};

  ObjectCreate("Arrow", OBJ_ARROW, WindowFind(IndName), 0, 0);
  ObjectSet("Arrow", OBJPROP_COLOR, ColorArrow);

  CreateVertLine("BeginInterval", ColorLine);
  CreateVertLine("EndInterval", ColorLine);

  CreateObject("Depth", "Depth", 12, Xcoord, Ycoord - 20 - Avg, 0, FALSE, FALSE, ColorText);
  CreateObject("Deviation", "Deviation", 12, Xcoord, Ycoord + 20 - Avg, 0, FALSE, FALSE, ColorText);
  CreateObject("Recycle", "Recycle", 12, Xcoord, Ycoord + 40 - Avg, 0, FALSE, FALSE, ColorText);
  CreateObject("Method", Methods[Method - 1], 12, Xcoord, Ycoord + 60 - Avg, 0, FALSE, FALSE, ColorText);

  if (SymbolPos < AmountSymbols)
    CreateObject("SymbolKoef", "SymbolKoef", 12, Xcoord, Ycoord + 80 - Avg, 0, FALSE, FALSE, ColorText);

  for (i = 0; i <= (AmountSymbols - 1) * XStep / 9; i++)
    Tmp = Tmp + "_";

  CreateObject("Top", Tmp, 12, Xcoord, Ycoord - 5 - Avg, 0, FALSE, TRUE, ColorAxis);
  CreateObject("Bottom", Tmp, 12, Xcoord, Ycoord - 5 + Avg, 0, FALSE, TRUE, ColorAxis);

  for (i = 0; i < AmountSymbols; i++)
  {
    CreateObjectBar(Symbols[i], Xcoord, Ycoord);

    Xcoord += XStep;
  }

  return;
}

void SetBar( string Name, double Value )
{
  int i, Pos;
  string Tmp;
  int Avg = Height / 2;

  HideObject(Name + "Plus", TRUE);
  HideObject(Name + "Minus", TRUE);

  if (Value >= 0)
    Tmp = "Plus";
  else
    Tmp = "Minus";

  ModifyTextObject(Name + Tmp, DoubleToStr(Value, 4));
  HideObject(Name + Tmp, FALSE);

  for (i = 0; i <= Height; i++)
   HideObject(Name + i, TRUE);

  Pos = Value * Avg;

  if (Value >= 0)
    for (i = Avg; i >= Avg - Pos; i--)
      HideObject(Name + i, FALSE);
  else
    for (i = Avg; i <= Avg - Pos; i++)
      HideObject(Name + i, FALSE);

  return;
}

int GetTimePos( int SearchTime )
{
  int LeftTime, RightTime, PosTime;
  int Left, Right, Pos = 0;

  Left = 0;
  Right = MatrixRows - 1;

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

void ModifyTextObject( string Name, string Text )
{
  int Color = ObjectGet(Name, OBJPROP_COLOR);
  int FontSize = ObjectGet(Name, OBJPROP_FONTSIZE);

  ObjectSetText(Name, Text, FontSize, FontName, Color);

  return;
}

void SetArrow()
{
  ObjectSet("Arrow", OBJPROP_TIME1, Times[MatrixRows - 1]);
  ObjectSet("Arrow", OBJPROP_PRICE1, iIF(SymbolPos < AmountSymbols, MathAbs(Vectors[SymbolPos][MatrixRows - 1]), Recycles[MatrixRows - 1]));

  return;
}

void SetVertLine( string Name, int Pos)
{
  ObjectSet(Name, OBJPROP_TIME1, Pos);

  return;
}

void DrawVector( double& Vector[] )
{
  string Tmp;

  SetArrow();

  SetVertLine("BeginInterval", Times[MatrixRows - Depth]);
  SetVertLine("EndInterval", Times[MatrixRows - 1]);

  Tmp = "Depth = " + Depth + " bars (" + TimeToStr(Times[MatrixRows - Depth]) + " - " + TimeToStr(Times[MatrixRows - 1]) + ")";
  ModifyTextObject("Depth", Tmp);

  Tmp = "Deviation = " + Divers[MatrixRows - 1];
  ModifyTextObject("Deviation", Tmp);

  Tmp = "Recycle = " + Recycles[MatrixRows - 1];
  ModifyTextObject("Recycle", Tmp);

  if (SymbolPos < AmountSymbols)
  {
    Tmp = Symbol() + " Koef = " + MathAbs(Vector[SymbolPos]);
    ModifyTextObject("SymbolKoef", Tmp);
  }

  for (int i = 0; i < AmountSymbols; i++)
    SetBar(Symbols[i], Vector[i]);

  WindowRedraw();

  return;
}

void SaveData( string FileName, int Pos )
{
  int handle = FileOpen(FileName, FILE_BIN|FILE_READ|FILE_WRITE);

  FileSeek(handle, 0, SEEK_END);

  while (Pos < MatrixRows)
  {
    FileWriteInteger(handle, Times[Pos]);
    FileWriteDouble(handle, Recycles[Pos]);
    FileWriteDouble(handle, Divers[Pos]);

    for (int i = 0; i < AmountSymbols; i++)
      FileWriteDouble(handle, Vectors[i][Pos]);

    Pos++;
  }

  FileClose(handle);

  return;
}

double iIF( bool Cond, double Num1, double Num2 )
{
  if (Cond)
    return(Num1);

  return(Num2);
}

void start()
{
  static bool FirstRun = TRUE;
  static int PrevTime = 0;
  string Name = UName + "Done";
  bool Var, FlagChange = FALSE;
  int PrevPos, Pos;

  if (FirstRun)
  {
    CreateBars(50, 50 + Height / 2, BarStep);

    FirstRun = FALSE;
  }

  if (PrevTime != Time[0])
  {
    PrevTime = Time[0];

    GlobalVariableSet(UName + "LastTime", Time[0]);

    GetBaseMatrix();

    PrevPos = CurrPos;

    while (CurrPos < MatrixRows)
    {
      GetCvarMatrix(CurrPos, Depth);

      Divers[CurrPos] = GetOptimalVector(V, Method, Correlation);
      Recycles[CurrPos] = GetRecycle(CurrPos, Depth, V, Correlation);

      Pos = iBarShift(Symbol(), Period(), Times[CurrPos]);

      Buffer[Pos] = iIF(SymbolPos < AmountSymbols, MathAbs(V[SymbolPos]), Recycles[CurrPos]);
      Buffer2[Pos] = iIF(SymbolPos < AmountSymbols, MathAbs(V[SymbolPos]), Divers[CurrPos]);
      Buffer3[Pos] = iIF(SymbolPos < AmountSymbols, MathAbs(V[SymbolPos]), -Divers[CurrPos]);

      for (int i = 0; i < AmountSymbols; i++)
        Vectors[i][CurrPos] = V[i];

      CurrPos++;
    }

    if (PrevPos < MatrixRows)
    {
      DrawVector(V);

      SaveData(UName + "i.dat", PrevPos);

      FlagChange = TRUE;
    }
  }

  if (GlobalVariableCheck(Name))
  {
    GetSaveData(UName + ".dat", UName + "i.dat");
    DrawVector(V);

    GlobalVariableDel(Name);
    FlagChange = TRUE;
  }

  if (FlagChange)
    GlobalVariableSet(UName, GlobalVariableGet(UName) + 1);

  return;
}