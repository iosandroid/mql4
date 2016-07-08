#property indicator_separate_window
#property indicator_buffers 1
#property indicator_color1 Red
#property indicator_width1 1

#define MAX_AMOUNTSYMBOLS 15
#define MAX_POINTS 100000

extern int Margin = 1000;
extern color ColorText = Gray;

string FontName = "Arial";

string SymbolsStr;
int Depth;

double Buffer[];

string Symbols[MAX_AMOUNTSYMBOLS];
double BaseMatrix[][MAX_POINTS];
double Means[], Vars[], SVector[];
int Times[MAX_POINTS];
double Recycles[];
int AmountSymbols, MatrixRows;
double Vectors[][MAX_POINTS];
int StartTime;
double Data[];
double Lots[], Spreads[], TickValues[];

string IndName = "RecycleProfit";
string UName;

void GetConfig( string FileName )
{
  int handle = FileOpen(FileName, FILE_CSV|FILE_READ);

  SymbolsStr = FileReadString(handle);
  FileReadNumber(handle); // Correlation
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
      BaseMatrix[i][MatrixRows] = GetPrice(Symbols[i], CurrTime);

    Times[MatrixRows] = CurrTime;

    MatrixRows++;

    CurrTime = GetNextTime(CurrTime);
  }

  return;
}

double TrueTickValue( string Symb )
{
  double TickValue = MarketInfo(Symb, MODE_TICKVALUE);
  double Tmp = MarketInfo(Symb, MODE_MARGININIT);

  if ((MarketInfo(Symb, MODE_MARGINCALCMODE) > 0) && (Tmp > 0))
    TickValue *=  MarketInfo(Symb, MODE_MARGINREQUIRED) / Tmp;

  return(TickValue);
}

void GetMarket( int Pos )
{
  double Tmp = 0;

  RefreshRates();

  for (int i = 0; i < AmountSymbols; i++)
  {
    Spreads[i] = MarketInfo(Symbols[i], MODE_SPREAD) * MarketInfo(Symbols[i], MODE_POINT);
    TickValues[i] = TrueTickValue(Symbols[i]) / MarketInfo(Symbols[i], MODE_TICKSIZE);

    if (Recycles[Pos] < 0)
      Lots[i] = Vectors[i][Pos] / (MarketInfo(Symbols[i], MODE_ASK) * TickValues[i]);
    else
      Lots[i] = -Vectors[i][Pos] / (MarketInfo(Symbols[i], MODE_ASK) * TickValues[i]);

    Tmp += MathAbs(Lots[i]) * MarketInfo(Symbols[i], MODE_MARGINREQUIRED);

    if (MarketInfo(Symbols[i], MODE_MARGINREQUIRED) == 0)
      Alert("Warning: MODE_MARGINREQUIRED(" + Symbols[i] + ") = 0.");
  }

  Tmp /= Margin;

  for (i = 0; i < AmountSymbols; i++)
    Lots[i] /= Tmp;

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
    FileReadDouble(handle); // Divs[i]

    FileReadArray(handle, V, 0, AmountSymbols);

    for (j = 0; j < AmountSymbols; j++)
      Vectors[j][i] = V[j];

    i++;
  }

  FileClose(handle);

  MatrixRows = i;

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

  ArrayResize(Lots, AmountSymbols);
  ArrayResize(Spreads, AmountSymbols);
  ArrayResize(TickValues, AmountSymbols);

  StartTime = GetStartTime(UName + ".dat");

  GetBaseMatrix();

  ArrayResize(Recycles, MatrixRows);
  ArrayResize(Times, MatrixRows);

  ArrayResize(Data, MatrixRows);

  GetData(UName + ".dat");

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

  for (i = 0; i < MatrixRows; i++)
    Buffer[iBarShift(Symbol(), Period(), Times[i])] = Data[i];

  for (i = 0; i < AmountSymbols; i++)
    ModifyTextObject(Symbols[i] + "_lots", Symbols[i] + " = " + Lots[i] + " lots");

  WindowRedraw();

  return;
}

void Check()
{
  static int PrevEndInterval = 0;
  int EndInterval, Pos;
  int i, j;
  double Profit = 0, InitProfit = 0;

  EndInterval = ObjectGet("EndInterval", OBJPROP_TIME1);

  if (EndInterval != PrevEndInterval)
  {
    PrevEndInterval = EndInterval;

    Pos = GetTimePos(EndInterval);

    GetMarket(Pos);

    for (i = 0; i < AmountSymbols; i++)
    {
      TickValues[i] *= MathAbs(Lots[i]);
      InitProfit -= Spreads[i] * TickValues[i];
      Spreads[i] = BaseMatrix[i][Pos];
    }

    for (i = 0; i < MatrixRows; i++)
    {
      Profit = InitProfit;

      for (j = 0; j < AmountSymbols; j++)
        if (Lots[j] > 0)
          Profit += (BaseMatrix[j][i] - Spreads[j]) * TickValues[j];
        else
          Profit -= (BaseMatrix[j][i] - Spreads[j]) * TickValues[j];

      Data[i] = Profit;
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
  for (int i = 0; i < AmountSymbols; i++)
  {
    CreateObject(Symbols[i] + "_lots", Symbols[i], 12, Xcoord, Ycoord, 0, FALSE, FALSE, ColorText);

    Ycoord += 20;
  }

  return;
}

void Init()
{
  static bool FirstRun = TRUE;

  if (!FirstRun)
    return;

  IndName = IndName + ": Margin = " + Margin;

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