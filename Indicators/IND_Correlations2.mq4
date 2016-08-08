//https://www.mql5.com/ru/code/10461
#property show_inputs

#define TWO_SYMBOLS 2

#define DEPTH 0
#define MEAN 1
#define STDEV 2

#define CORRELATION 0
#define NUM 1

#define MAX_POINTS 1000000

extern datetime StartTime = D'2011.01.01';
extern int StartDepth = 12;
extern int EndDepth = 576;
extern int StepDepth = 12;
extern int Shift = 0;
extern int Method = 2;

string SymbolsAll[], Symbols[TWO_SYMBOLS], SymbolsDescription[];
double BaseMatrix[TWO_SYMBOLS][MAX_POINTS], MOMatrix[TWO_SYMBOLS][MAX_POINTS];
double CvarMatrix[TWO_SYMBOLS][TWO_SYMBOLS];
double Means[TWO_SYMBOLS], SVector[TWO_SYMBOLS];
int Times[MAX_POINTS], Shifts[TWO_SYMBOLS];
int AmountSymbols, MatrixRows;
int CurrPos, CurrTime;

string StrOut[];
double Data[][3], Corr[][2];
int Amount, AmountDepth, Count = 0;

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

  for (i = 0; i < TWO_SYMBOLS;, i++)
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

  for (i = 0; i < TWO_SYMBOLS;, i++)
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

string iIF( bool Cond, string Str1, string Str2 )
{
  if (Cond)
    return(Str1);

  return(Str2);
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

void GetVectorData1( double &Vector[], double &Mean, double &StDev )
{
  int i, Amount = ArraySize(Vector);
  double Tmp;

  Mean = 0;
  StDev = 0;

  for (i = 0; i < Amount; i++)
    Mean += Vector[i];

  Mean /= Amount;

  for (i = 0; i < Amount; i++)
  {
    Tmp = Vector[i] - Mean;

    StDev += Tmp * Tmp;
  }

  StDev = MathSqrt(StDev / Amount);

  return;
}

void GetVectorData2( double &Vector[], double &Mean, double &StDev )
{
  int i, Amount = ArraySize(Vector);
  int Amount2 = 0;
  double Tmp;

  Mean = 0;
  StDev = 0;

  for (i = 0; i < Amount; i++)
    Mean += Vector[i];

  Mean /= Amount;

  if (Mean > 0)
    for (i = 0; i < Amount; i++)
    {
      Tmp = Vector[i] - Mean;

      if (Tmp < 0)
      {
        StDev += Tmp * Tmp;
        Amount2++;
      }
    }
  else
    for (i = 0; i < Amount; i++)
    {
      Tmp = Vector[i] - Mean;

      if (Tmp > 0)
      {
        StDev += Tmp * Tmp;
        Amount2++;
      }
    }

  if (Amount2 > 0)
    StDev = MathSqrt(StDev / Amount2);

  return;
}

void InitCorrelation2( string &Symbol1, string &Symbol2 )
{
  Symbols[0] = iIF(Shift < 0, Symbol2, Symbol1);
  Symbols[1] = iIF(Shift < 0, Symbol1, Symbol2);

  Shifts[0] = 0;
  Shifts[1] = MathAbs(Shift);

  CurrTime = GetStartTime(iTime(Symbol1, Period(), iBarShift(Symbol1, Period(), StartTime) + EndDepth));
  MatrixRows = 0;
  CurrPos = EndDepth;

  GetBaseMatrix();

  while (Times[CurrPos] < StartTime)
    CurrPos++;

  return;
}

void GetData()
{
  int i, j, Depth;
  int StartCurrPos = CurrPos;
  static double Correlations[];
  double Mean, StDev;

  ArrayResize(Correlations, MatrixRows - CurrPos);

  StartCurrPos = CurrPos;

  for (i = 0; i < AmountDepth; i++)
  {
    Depth = Data[i][DEPTH];

    GetCvarMatrix(CurrPos - 1, Depth);

    j = 0;

    while (CurrPos < MatrixRows)
    {
      GetNextCvarMatrix2(CurrPos, Depth);

      Correlations[j] = GetCorrelation();
      j++;

      CurrPos++;
    }

    if (Method == 1)
      GetVectorData1(Correlations, Mean, StDev);
    else
      GetVectorData2(Correlations, Mean, StDev);

    Data[i][MEAN] = Mean;
    Data[i][STDEV] = StDev;

    CurrPos = StartCurrPos;
  }

  return;
}

void SaveData( string FileName )
{
  int handle =FileOpen(FileName, FILE_CSV|FILE_WRITE);

  for (int i = 0; i < AmountDepth; i++)
    FileWrite(handle, DoubleToStr(Data[i][DEPTH], 0) + " " + DoubleToStr(Data[i][MEAN], 8) + " " + DoubleToStr(Data[i][STDEV], 8));

  FileClose(handle);

  return;
}

double GetCorrelation2( string &Symbol1, string &Symbol2, string &StrOut )
{
  int i, iMax;
  double Mean, StDev, Max = -2, Tmp;
  int Len = StringLen(DoubleToStr(EndDepth, 0));

  InitCorrelation2(Symbol1, Symbol2);
  GetData();

  for (i = 0; i < AmountDepth; i++)
  {
    Mean = Data[i][MEAN];
    StDev = Data[i][STDEV];

    if (Mean < 0)
      Mean = -Mean;

    if (Mean - StDev > Max)
    {
      Max = Mean - StDev;
      iMax = i;
    }
  }

  SaveData(WindowExpertName() + "\\" + Symbol1 + " - " + Symbol2 + ".prn");

  if (Max > 0)
  {
    if (Data[iMax][MEAN] > 0)
      StrOut = "Corr2 =  " + DoubleToStr(Max, 4) + " (Goo";
    else
      StrOut = "Corr2 = " + DoubleToStr(-Max, 4) + " (Goo";
  }
  else if (Data[iMax][MEAN] > 0)
    StrOut = "Corr2 = " + DoubleToStr(Max, 4) + "  (Ba";
  else
    StrOut = "Corr2 =  " + DoubleToStr(-Max, 4) + "  (Ba";

  StrOut = StrOut + "d), Depth = " + StrNumToLen(DoubleToStr(Data[iMax][DEPTH], 0), Len, TRUE);

  return(Max);
}

int SymbolsList( string &Symbols[] )
{
   int Offset, SymbolsNumber;

   int hFile = FileOpenHistory("symbols.sel", FILE_BIN|FILE_READ);
   SymbolsNumber = (FileSize(hFile) - 4) / 128;
   Offset = 116;

   ArrayResize(Symbols, SymbolsNumber);

   FileSeek(hFile, 4, SEEK_SET);

   for(int i = 0; i < SymbolsNumber; i++)
   {
      Symbols[i] = FileReadString(hFile, 12);
      FileSeek(hFile, Offset, SEEK_CUR);
   }

   FileClose(hFile);

   return(SymbolsNumber);
}

//+------------------------------------------------------------------+
//| Функция возвращает расшифрованное название символа               |
//+------------------------------------------------------------------+
string SymbolDescription(string SymbolName)
{
   string SymbolDescription = "";

// Открываем файл с описанием символов

   int hFile = FileOpenHistory("symbols.raw", FILE_BIN|FILE_READ);
   if(hFile < 0) return("");

// Определяем количество символов, зарегистрированных в файле

   int SymbolsNumber = FileSize(hFile) / 1936;

// Ищем расшифровку символа в файле

   for(int i = 0; i < SymbolsNumber; i++)
   {
      if(FileReadString(hFile, 12) == SymbolName)
      {
         SymbolDescription = FileReadString(hFile, 64);
         break;
      }
      FileSeek(hFile, 1924, SEEK_CUR);
   }

   FileClose(hFile);

   return(SymbolDescription);
}

//+------------------------------------------------------------------+
//| Функция определяет тип инструмента                               |
//+------------------------------------------------------------------+
string SymbolType( string SymbolName )
{
   int GroupNumber = -1;
   string SymbolGroup = "";

// Открываем файл с описанием символов

   int hFile = FileOpenHistory("symbols.raw", FILE_BIN|FILE_READ);
   if(hFile < 0) return("");

// Определяем количество символов, зарегистрированных в файле

   int SymbolsNumber = FileSize(hFile) / 1936;

// Ищем символ в файле

   for(int i = 0; i < SymbolsNumber; i++)
   {
      if(FileReadString(hFile, 12) == SymbolName)
      {
      // Определяем номер группы

         FileSeek(hFile, 1936*i + 100, SEEK_SET);
         GroupNumber = FileReadInteger(hFile);

         break;
      }
      FileSeek(hFile, 1924, SEEK_CUR);
   }

   FileClose(hFile);

   if(GroupNumber < 0) return("");

// Открываем файл с описанием групп

   hFile = FileOpenHistory("symgroups.raw", FILE_BIN|FILE_READ);
   if(hFile < 0) return("");

   FileSeek(hFile, 80*GroupNumber, SEEK_SET);
   SymbolGroup = FileReadString(hFile, 16);

   FileClose(hFile);

   return(SymbolGroup);
}

void init()
{
  int i;

  Comment(WindowExpertName() + " (StartTime = " + TimeToStr(StartTime) + ":\nStarting (wait) ...");

  AmountSymbols = SymbolsList(SymbolsAll);

  ArrayResize(SymbolsDescription, AmountSymbols);

  Amount = AmountSymbols * (AmountSymbols - 1) / 2;

  ArrayResize(Corr, Amount);
  ArrayResize(StrOut, Amount);

  for (i = 0; i < AmountSymbols; i++)
    SymbolsDescription[i] = /*SymbolType(SymbolsAll[i]) + "\\" + */SymbolDescription(SymbolsAll[i]);

  ArrayResize(Data, EndDepth);

  for (i = StartDepth; i <= EndDepth; i += StepDepth)
  {
    Data[AmountDepth][DEPTH] = i;
    AmountDepth++;
  }

  ArrayResize(Data, AmountDepth);

  return;
}

string StrNumToLen( string Num, int Len, bool Space = FALSE )
{
  string Str;

  if (Space)
    Str = " ";
  else
    Str = "0";

  Len -= StringLen(Num);

  while (Len > 0)
  {
    Num = Str + Num;
    Len--;
  }

  return(Num);
}

void SaveCorr( string FileName )
{
  int Pos, handle = FileOpen(FileName, FILE_CSV|FILE_WRITE);
  int Len = StringLen(DoubleToStr(Count, 0));

  Comment(WindowExpertName() + " (StartTime = " + TimeToStr(StartTime) + ":\nSaving data...");

  ArraySort(Corr, WHOLE_ARRAY, 0, MODE_DESCEND);

  for (int i = 0; i < Count; i++)
  {
    Pos = Corr[i][NUM];

    FileWrite(handle, StrNumToLen(i + 1, Len) + ". " + StrOut[Pos]);
  }

  FileClose(handle);

  return;

}

void SetComment( int TimeInterval, int Count )
{
  string Str = WindowExpertName() + " (StartTime = " + TimeToStr(StartTime) + "):\n";

  Str = Str + "Amount = " + Amount + " pairs\n";
  Str = Str + "Ready: " + DoubleToStr(100.0 * Count / Amount, 2) + "%\n";

  if (TimeInterval != 0)
    Str = Str + "Performance = "  + DoubleToStr(Count * 1000.0 / TimeInterval, 2) + " pairs/sec.\n";

  Str = Str + "Elapsed time: " + TimeToStr(TimeInterval / 1000, TIME_SECONDS) + "\n";
  Str = Str + "Remaining time: " + TimeToStr(1.0 * (Amount - Count) * TimeInterval / (1000 * Count), TIME_SECONDS);

  Comment(Str);

  return;
}

void deinit()
{
  ArrayResize(Corr, Count);

  SaveCorr(WindowExpertName() + ".txt");

  Comment("");

  return;
}

void start()
{
  int i, j;
  double Correlation;
  int Start, CurrentTime, PrevTime = 0;
  int BeginTime, EndTime;
  int Len = StringLen(DoubleToStr(Amount, 0));
  string Symbol1, Symbol2, Str;

  Start = GetTickCount();

  for (i = 0; i < AmountSymbols - 1; i++)
  {
    Symbol1 = SymbolsAll[i];

    for (j = i + 1; j < AmountSymbols; j++)
    {
      Symbol2 = SymbolsAll[j];

      RefreshRates();

      Corr[Count][NUM] = Count;
      Corr[Count][CORRELATION] = GetCorrelation2(Symbol1, Symbol2, Str);

      BeginTime = Times[CurrPos];
      EndTime = Times[MatrixRows - 1];

      MatrixRows -= CurrPos;

      StrOut[Count] = Str + ", " + Symbol1 + " - " + Symbol2 +  ", bars = " + MatrixRows +
                            " (" + TimeToStr(BeginTime) + " - " + TimeToStr(EndTime) +
                            "), " + SymbolsDescription[i] + " - " + SymbolsDescription[j];

      Print(StrNumToLen(Count + 1, Len) + "/" + Amount + ": " + StrOut[Count]);

      Count++;

      CurrentTime = GetTickCount();

      if ((CurrentTime - PrevTime > 1000) || (CurrentTime - PrevTime < -1000))
      {
        PrevTime = CurrentTime;

        SetComment(CurrentTime - Start, Count);
      }

      if (IsStopped())
        return;
    }
  }

  return;
}