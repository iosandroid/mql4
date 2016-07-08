#property indicator_separate_window
#property indicator_buffers 1
#property indicator_color1 Red
#property indicator_width1 1
#property indicator_levelcolor Blue
#property indicator_levelwidth 1

#define MAX_AMOUNTSYMBOLS 15
#define MAX_POINTS 100000

extern color ColorText = Gray;

string FontName = "Arial";

string SymbolsStr;
int Depth;
bool Correlation;

double Buffer[];

string Symbols[MAX_AMOUNTSYMBOLS];
double BaseMatrix[][MAX_POINTS];
double Means[], Vars[], SVector[];
int Times[MAX_POINTS];
double Recycles[], Divs[];
int AmountSymbols, MatrixRows;
double Vectors[][MAX_POINTS];
int StartTime;
double Data[];

string IndName = "RecycleShowMe";
string UName;

void GetConfig( string FileName )
{
  int handle = FileOpen(FileName, FILE_CSV|FILE_READ);

  SymbolsStr = FileReadString(handle);
  Correlation = (FileReadNumber(handle) == 1);
  Depth = FileReadNumber(handle);

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

datetime GetStartTime( string FileName )
{
  int handle = FileOpen(FileName, FILE_BIN|FILE_READ);
  int T[], Time0, CurrTime, Pos = 0;

  if (FileSize(handle) == 0)
    return(0);
  Time0 = FileReadInteger(handle);
  FileClose(handle);

  ArrayResize(T, Depth);

  CurrTime = iTime(Symbols[0], Period(), iBarShift(Symbols[0], Period(), Time0) + Depth);

  while (CurrTime < Time0)
  {
    T[Pos] = CurrTime;

    if (Pos < Depth - 1)
      Pos++;
    else
      Pos = 0;

    CurrTime = GetNextTime(CurrTime);
  }

  return(T[Pos]);
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
  int i, CurrTime = StartTime;

  MatrixRows = 0;

  while (CurrTime < Time[0])
  {
    for (i = 0; i < AmountSymbols; i++)
      BaseMatrix[i][MatrixRows] = 1000 * MathLog(GetPrice(Symbols[i], CurrTime));

    Times[MatrixRows] = CurrTime;

    MatrixRows++;

    CurrTime = GetNextTime(CurrTime);
  }

  return;
}

void GetData( string FileName )
{
  int i = Depth, j;
  double V[];
  int handle = FileOpen(FileName, FILE_BIN|FILE_READ);

  ArrayResize(V, AmountSymbols);

  while (FileTell(handle) < FileSize(handle))
  {
    Times[i] = FileReadInteger(handle);
    Recycles[i] = FileReadDouble(handle);
    Divs[i] = FileReadDouble(handle);

    FileReadArray(handle, V, 0, AmountSymbols);

    for (j = 0; j < AmountSymbols; j++)
      Vectors[j][i] = V[j];

    i++;
  }

  FileClose(handle);

  MatrixRows = i;

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

void GetVars( int Pos, int Len )
{
  int i, j;
  double Cvar, Tmp;

  GetMeans(Pos, Len);

  for (i = 0; i < AmountSymbols; i++)
  {
    Cvar = 0;

    for (j = Pos; j > Pos - Len; j--)
    {
      Tmp = BaseMatrix[i][j] - Means[i];

      Cvar += Tmp * Tmp;
    }

    Vars[i] = Cvar / Len;
  }

  return;
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

void GetNextVars( int Pos, int Len )
{
  int Pos2 = Pos - Len;
  double Tmp1, Tmp2, Tmp3;

  GetNextMeans(Pos, Len);

  for (int i = 0; i < AmountSymbols; i++)
  {
    Tmp1 = SVector[i];
    Tmp2 = BaseMatrix[i][Pos] - Means[i];
    Tmp3 = BaseMatrix[i][Pos2] - Means[i];

    Vars[i] += Tmp1 * Tmp1 + (Tmp2 * Tmp2 - Tmp3 * Tmp3) / Len;

    if (Vars[i] < 0)
      Vars[i] = 0;
  }

  return;
}

void ChangeVectors()
{
  int i, CurrPos = Depth;

  ArrayResize(Vars, AmountSymbols);
  ArrayResize(SVector, AmountSymbols);

  GetVars(CurrPos - 1, Depth);

  while (CurrPos < MatrixRows)
  {
    GetNextVars(CurrPos, Depth);

    for (i = 0; i < AmountSymbols; i++)
    {
      if (Vars[i] == 0)
        Vectors[i][CurrPos] = 0;
      else
        Vectors[i][CurrPos] /= MathSqrt(Vars[i]);
    }

    CurrPos++;
  }

  return;
}

void init()
{
  UName = "hwnd" + WindowHandle(Symbol(), Period());

  if (!GlobalVariableCheck(UName))
    return;

  IndicatorDigits(8);
  SetIndexStyle(0, DRAW_LINE, DRAW_LINE);
  SetIndexBuffer(0, Buffer);

  GetConfig(UName + ".ini");

  AmountSymbols = StrToStringS(SymbolsStr, ",", Symbols);

  ArrayResize(Symbols, AmountSymbols);
  ArrayResize(BaseMatrix, AmountSymbols);
  ArrayResize(Means, AmountSymbols);
  ArrayResize(Vectors, AmountSymbols);

  StartTime = GetStartTime(UName + ".dat");

  GetBaseMatrix();

  ArrayResize(Recycles, MatrixRows);
  ArrayResize(Times, MatrixRows);
  ArrayResize(Divs, MatrixRows);

  ArrayResize(Data, MatrixRows);

  GetData(UName + ".dat");

  if (Correlation)
    ChangeVectors();

  return(TRUE);
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

void DrawData( int Pos )
{
  int i;
  string Str = ")";
  double Tmp = Data[Pos];
  double Max = MathAbs(Tmp);
  int NullTime, NullBar, MaxBar = Pos;

  SetLevelValue(0, Divs[Pos]);
  SetLevelValue(1, -Divs[Pos]);

  for (i = 0; i < MatrixRows; i++)
    Buffer[iBarShift(Symbol(), Period(), Times[i])] = Data[i];

  for (i = Pos + 1; i < MatrixRows; i++)
    if (Data[i] * Tmp <= 0)
      break;
    else if (MathAbs(Data[i]) > Max)
    {
      Max = MathAbs(Data[i]);
      MaxBar = i;
    }

  NullBar = i;

  if (NullBar == MatrixRows)
  {
    NullBar--;
    Str = " - EndTime)";

    ObjectSet("Null1", OBJPROP_TIME1, 0);
  }
  else
    ObjectSet("Null1", OBJPROP_TIME1, Times[NullBar]);

  Max = Data[MaxBar];
  NullTime = Times[NullBar];
  NullBar -= Pos;
  MaxBar -= Pos;

  ModifyTextObject("NullBar1", "NullBar1 = " + NullBar + " (" + TimeToStr(NullTime) + Str);
  ModifyTextObject("MaxBar1", "MaxBar1 = " + MaxBar + " (" + Max + ")");

  Pos -= Depth - 1;

  Tmp = Data[Pos];
  Max = MathAbs(Tmp);
  MaxBar = Pos;

  for (i = Pos - 1; i >= 0; i--)
    if (Data[i] * Tmp <= 0)
      break;
    else if (MathAbs(Data[i]) > Max)
    {
      Max = MathAbs(Data[i]);
      MaxBar = i;
    }

  NullBar = i;

  if (NullBar < 0)
  {
    NullBar++;
    Str = " - BeginTime)";

    ObjectSet("Null2", OBJPROP_TIME1, 0);
  }
  else
  {
    Str = ")";

    ObjectSet("Null2", OBJPROP_TIME1, Times[NullBar]);
  }

  Max = Data[MaxBar];
  NullTime = Times[NullBar];
  NullBar = Pos - NullBar;
  MaxBar = Pos - MaxBar;

  ModifyTextObject("NullBar2", "NullBar2 = " + NullBar + " (" + TimeToStr(NullTime) + Str);
  ModifyTextObject("MaxBar2", "MaxBar2 = " + MaxBar + " (" + Max + ")");

  WindowRedraw();

  return;
}

void Check()
{
  static int PrevEndInterval = 0;
  int EndInterval, Pos;
  int i, j;
  double Tmp, Mean = 0;

  EndInterval = ObjectGet("EndInterval", OBJPROP_TIME1);

  if (EndInterval != PrevEndInterval)
  {
    PrevEndInterval = EndInterval;

    Pos = GetTimePos(EndInterval);

    GetMeans(Pos, Depth);

    for (i = 0; i < AmountSymbols; i++)
      Mean -= Means[i] * Vectors[i][Pos];

    for (i = 0; i < MatrixRows; i++)
    {
      Tmp = Mean;

      for (j = 0; j < AmountSymbols; j++)
        Tmp += BaseMatrix[j][i] * Vectors[j][Pos];

      Data[i] = Tmp;
   }

    DrawData(Pos);
  }

  return;
}

void CreateObject( string Name, string Value, int FontSize, int Xcoord, int Ycoord, int Angle, bool Hide, bool Back, int Color )
{
  ObjectCreate(Name, OBJ_LABEL, WindowFind(IndName), 0, 0);
//  HideObject(Name, Hide);
  ObjectSet(Name, OBJPROP_ANGLE, Angle);
  ObjectSet(Name, OBJPROP_XDISTANCE, Xcoord);
  ObjectSet(Name, OBJPROP_YDISTANCE, Ycoord);
  ObjectSet(Name, OBJPROP_BACK, Back);
  ObjectSetText(Name, Value, FontSize, FontName, Color);

  return;
}

void ModifyTextObject( string Name, string Text )
{
  int Color = ObjectGet(Name, OBJPROP_COLOR);
  int FontSize = ObjectGet(Name, OBJPROP_FONTSIZE);

  ObjectSetText(Name, Text, FontSize, FontName, Color);

  return;
}

void CreateObjects( int Xcoord, int Ycoord )
{
  CreateObject("NullBar1", "NullBar1", 12, Xcoord, Ycoord, 0, FALSE, FALSE, ColorText);
  CreateObject("MaxBar1", "MaxBar1", 12, Xcoord, Ycoord + 20, 0, FALSE, FALSE, ColorText);
  CreateObject("NullBar2", "NullBar2", 12, Xcoord, Ycoord + 60, 0, FALSE, FALSE, ColorText);
  CreateObject("MaxBar2", "MaxBar2", 12, Xcoord, Ycoord + 80, 0, FALSE, FALSE, ColorText);

  ObjectCreate("Null1", OBJ_ARROW, WindowFind(IndName), 0, 0);
  ObjectSet("Null1", OBJPROP_ARROWCODE, 3);

  ObjectCreate("Null2", OBJ_ARROW, WindowFind(IndName), 0, 0);
  ObjectSet("Null2", OBJPROP_ARROWCODE, 3);

}

void Init()
{
  static bool FirstRun = TRUE;

  if (!FirstRun)
    return;

  IndicatorShortName(IndName);

  CreateObjects(5, 15);

  FirstRun = FALSE;

  return;
}

void start()
{
  Init();

  Check();

  return;
}