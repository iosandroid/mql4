#define PAUSE 100

#define MAX_AMOUNTSYMBOLS 15
#define MAX_POINTS 100000

string SymbolsStr;
int Height, Depth;

string Symbols[MAX_AMOUNTSYMBOLS];
int AmountSymbols;

double Vectors[][MAX_POINTS], Divers[MAX_POINTS], Recycles[MAX_POINTS];
int CurrTime, Times[MAX_POINTS];

int MatrixRows;

string UName, SymbolPosName;
double V[];
int SymbolPos;

int Global, PrevGlobal, PrevTime, PrevEndInterval;

string FontName = "Arial";

void GetConfig( string FileName )
{
  int handle = FileOpen(FileName, FILE_CSV|FILE_READ);

  SymbolsStr = FileReadString(handle);

  FileReadNumber(handle); // Correlation
  Depth = FileReadNumber(handle);
  FileReadNumber(handle); // Method
  FileReadNumber(handle); // Iterations
  Height = FileReadNumber(handle);

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

int GetRightSideTime()
{
  static int Shift = 0;
  static int PrevPos = 0;
  int Pos, EndInterval;

  Pos = WindowFirstVisibleBar() - WindowBarsPerChart();

  if (Pos < 0)
    Pos = 0;

  if (PrevPos == Pos)
  {
    EndInterval = ObjectGet("EndInterval", OBJPROP_TIME1);

    if (EndInterval != PrevEndInterval)
    {
      if ((EndInterval > Times[MatrixRows - 1]) || (EndInterval < Times[Depth]))
        Shift = 0;
      else
        Shift = iBarShift(Symbol(), Period(), EndInterval) - Pos;

      PrevEndInterval = EndInterval;
    }
  }

  PrevPos = Pos;
  Pos += Shift;

  return(Time[iBarShift(Symbol(), Period(), GlobalVariableGet(UName + "LastTime")) + Pos]);
}

void GetData( string FileName )
{
  int i;
  int handle = FileOpen(FileName, FILE_BIN|FILE_READ);

  ArrayResize(Vectors, AmountSymbols);

  MatrixRows = 0;

  while (FileTell(handle) < FileSize(handle))
  {
    Times[MatrixRows] = FileReadInteger(handle);
    Recycles[MatrixRows] = FileReadDouble(handle);
    Divers[MatrixRows] = FileReadDouble(handle);

    for (i = 0; i < AmountSymbols; i++)
      Vectors[i][MatrixRows] = FileReadDouble(handle);

    MatrixRows++;
  }

  FileClose(handle);

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

void GetVector( int time, double& V[] )
{
  int Pos = GetTimePos(time);

  for (int i = 0; i < AmountSymbols; i++)
    V[i] = Vectors[i][Pos];

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

double iIF( bool Cond, double Num1, double Num2 )
{
  if (Cond)
    return(Num1);

  return(Num2);
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
  int Pos = GetTimePos(CurrTime);

  ObjectSet("Arrow", OBJPROP_TIME1, Times[Pos]);
  ObjectSet("Arrow", OBJPROP_PRICE1, iIF(SymbolPos < AmountSymbols, MathAbs(Vectors[SymbolPos][Pos]), Recycles[Pos]));

  return;
}

void SetVertLine( string Name, int Pos)
{
  ObjectSet(Name, OBJPROP_TIME1, Pos);

  return;
}

void DrawVector( double& Vector[] )
{
  string Tmp, Tmp2 = "";
  int time, Pos = GetTimePos(CurrTime);

  SetArrow();

  if (Pos < Depth - 1)
  {
    time = Time[iBarShift(Symbol(), Period(), Times[0]) + Depth - 1 - Pos];

    Tmp2 = " (about)";
  }
  else
    time = Times[Pos - Depth + 1];

  SetVertLine("BeginInterval", time);
  SetVertLine("EndInterval", Times[Pos]);

  Tmp = "Depth = " + Depth + " bars (" + TimeToStr(time) + Tmp2 + " - " + TimeToStr(Times[Pos]) + ")";
  ModifyTextObject("Depth", Tmp);

  Tmp = "Deviation = " + Divers[Pos];
  ModifyTextObject("Deviation", Tmp);

  Tmp = "Recycle = " + Recycles[Pos];
  ModifyTextObject("Recycle", Tmp);

  if (SymbolPos < AmountSymbols)
  {
    Tmp = Symbol() + " Koef = " + MathAbs(Vector[SymbolPos]);
    ModifyTextObject("SymbolKoef", Tmp);
  }

  for (int i = 0; i < AmountSymbols; i++)
    SetBar(Symbols[i], Vector[i]);

  WindowRedraw();

  if (TRUE)
    AddTick();

  return;
}

int GetCondition()
{
  int Cond = 0;

  if (!GlobalVariableCheck(UName))
    return(Cond); // 0

  Global = GlobalVariableGet(UName);

  if (Global == 0)
    return(Cond); // 0

  Cond++;

  if (PrevGlobal != Global)
    return(Cond); // 1

  Cond++;

  RefreshRates();
  CurrTime = GetRightSideTime();

  if (CurrTime != PrevTime)
    return(Cond);  // 2

  Cond++;

  return(Cond);
}

void Shadowing()
{
  UName = "hwnd" + WindowHandle(Symbol(), Period());
  SymbolPosName = UName + "SymbolPos";
  bool Flag = TRUE;

  while (!IsStopped())
  {
    switch (GetCondition())
    {
      case 0:
        Flag = TRUE;

        PrevGlobal = 0;

        break;
      case 1:
        if (Flag)
        {
          GetConfig(UName + ".ini");
          SymbolPos = GlobalVariableGet(SymbolPosName);

          AmountSymbols = StrToStringS(SymbolsStr, ",", Symbols);
          ArrayResize(V, AmountSymbols);

          PrevTime = 0;
          PrevEndInterval = ObjectGet("EndInterval", OBJPROP_TIME1);

          Flag = FALSE;
        }

        PrevGlobal = Global;

        GetData(UName + "i.dat");

        break;
      case 2:
        GetVector(CurrTime, V);
        DrawVector(V);

        PrevTime = CurrTime;

        break;
    }

    Sleep(PAUSE);
  }

  return;
}

void init()
{
  Shadowing();

  return;
}

void start()
{
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

