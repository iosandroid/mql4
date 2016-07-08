//https://www.mql5.com/ru/code/9924
#property show_inputs

#define MAX_POINTS 100000
#define TWO_SYMBOLS 2

extern datetime StartTime = D'2010.01.01';
extern bool Rank = FALSE; // FALSE - Pearson, TRUE - Spearman

string SymbolsAll[], Symbols[TWO_SYMBOLS], SymbolsDescription[];
double BaseMatrix[TWO_SYMBOLS][MAX_POINTS];
int AmountSymbols, MatrixRows;

double Vector1[][2], Vector2[][2];

double Correlations[];
string StrOut[];
int Amount;

datetime GetStartTime( datetime StartTime )
{
  datetime Tmp;
  int Pos;

  for (int i = 0; i < TWO_SYMBOLS; i++)
  {
    Pos = iBarShift(Symbols[i], Period(), StartTime);

    if (Pos == 0)
      return(-1);

    Tmp = iTime(Symbols[i], Period(), Pos);

    if (Tmp < StartTime)
      Tmp = iTime(Symbols[i], Period(), Pos - 1);

    StartTime = Tmp;
  }

  for (i = 0; i < AmountSymbols; i++)
    if (StartTime > iTime(Symbols[i], Period(), 0))
      return(-1);

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

    if (Pos[i] <= 0)
      return(-1);
  }
  MinTime = iTime(Symbols[0], Period(), Pos[0]);

  for (i = 1; i < TWO_SYMBOLS; i++)
  {
    Tmp = iTime(Symbols[i], Period(), Pos[i]);

    if (Tmp < MinTime)
      MinTime = Tmp;
  }

  return(MinTime);
}

double GetMean( int Pos )
{
  double Sum = 0;

  for (int i = 0; i < MatrixRows;, i++)
    Sum += BaseMatrix[Pos][i];

  if (MatrixRows != 0)
    Sum /= MatrixRows;

  return(Sum);
}

double GetCorrelation( int Pos1, int Pos2 )
{
  double Sum = 0;

  for (int i = 0; i < MatrixRows;, i++)
    Sum += BaseMatrix[Pos1][i] * BaseMatrix[Pos2][i];

  if (MatrixRows != 0)
    Sum /= MatrixRows;

  return(Sum);
}

int GetRank( double& Vector[][] )
{
  double Tmp;
  int i, Count;
  int Res = 0;

  ArraySort(Vector);

  for (i = 0; i < MatrixRows; i++)
  {
    Count = 0;

    while (i < MatrixRows - 1)
    {
      if (Vector[i][0] != Vector[i + 1][0])
        break;

      Count++;
      i++;
    }

    Tmp = i;

    if (Count > 0)
    {
      Tmp -= Count / 2.0;
      Res += Count * (Count + 1) * (Count + 2);
    }

    while (Count >= 0)
    {
      Vector[i - Count][0] = Vector[i - Count][1];
      Vector[i - Count][1] = Tmp;

      Count--;
    }
  }

  ArraySort(Vector);

  return(Res);
}

double GetSpearmanRankCorr()
{
  double Tmp, Res = 0;
  double N = MatrixRows;
  int A1, A2;

  A1 = GetRank(Vector1);
  A2 = GetRank(Vector2);

  for (int i = 0; i < MatrixRows; i++)
  {
    Tmp = Vector1[i][1] - Vector2[i][1];
    Res += Tmp * Tmp;
  }

  N *= N * N - 1;

  if ((A1 == 0) && (A2 == 0))
    Res = 1 - 6 * Res / N;
  else
    Res = (N - (A1 + A2) / 2.0 - 6 * Res) / MathSqrt((N - A1) * (N - A2));

  return(Res);
}

double GetCorr()
{
  double Res = 0;

  if (MatrixRows > 0)
  {
    if (Rank)
      Res = GetSpearmanRankCorr();
    else
      Res = GetCorrelation(0, 1);
  }

  return(Res);
}

int GetVectors( int StartTime )
{
  int i, j, CurrTime = StartTime, NextTime = StartTime;
  double Mean, Variance;

  ArrayResize(Vector1, MAX_POINTS);
  ArrayResize(Vector2, MAX_POINTS);

  MatrixRows = 0;

  while (NextTime >= 0)
  {
    CurrTime = NextTime;

    Vector1[MatrixRows][0] = GetPrice(Symbols[0], CurrTime);
    Vector1[MatrixRows][1] = MatrixRows;

    Vector2[MatrixRows][0] = GetPrice(Symbols[1], CurrTime);
    Vector2[MatrixRows][1] = MatrixRows;

    MatrixRows++;

    if (MatrixRows == MAX_POINTS)
      break;

    NextTime = GetNextTime(CurrTime);
  }

  ArrayResize(Vector1, MatrixRows);
  ArrayResize(Vector2, MatrixRows);

  return(CurrTime);
}

int GetBaseMatrix( int StartTime)
{
  int i, j, CurrTime = StartTime, NextTime = StartTime;
  double Mean, Variance;

  MatrixRows = 0;

  while (NextTime >= 0)
  {
    CurrTime = NextTime;

    for (i = 0; i < TWO_SYMBOLS; i++)
      BaseMatrix[i][MatrixRows] = MathLog(GetPrice(Symbols[i], CurrTime));

    MatrixRows++;

    if (MatrixRows == MAX_POINTS)
      break;

    NextTime = GetNextTime(CurrTime);
  }

  for (i = 0; i < TWO_SYMBOLS; i++)
  {
    Mean = GetMean(i);

    for (j = 0; j < MatrixRows; j++)
      BaseMatrix[i][j] -= Mean;
  }

  for (i = 0; i < TWO_SYMBOLS; i++)
  {
    Variance = GetCorrelation(i, i);
    Variance = MathSqrt(Variance);

    for (j = 0; j < MatrixRows; j++)
      BaseMatrix[i][j] /= Variance;
  }

  return(CurrTime);
}

int GetData( int StartTime )
{
  int Res;

  if (Rank)
    Res = GetVectors(StartTime);
  else
    Res = GetBaseMatrix(StartTime);

  return(Res);
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

void SetComment( int TimeInterval, int Count )
{
  string Str = WindowExpertName() + " (StartTime = " + TimeToStr(StartTime);

  if (Rank)
    Str = Str + ", Rank = TRUE):\n";
  else
    Str = Str + ", Rank = FALSE):\n";

  Str = Str + "Amount = " + Amount + " pairs\n";
  Str = Str + "Ready: " + DoubleToStr(100.0 * Count / Amount, 1) + "%\n";

  if (TimeInterval != 0)
    Str = Str + "Performance = "  + DoubleToStr(Count * 1000.0 / TimeInterval, 2) + " pairs/sec.\n";

  Str = Str + "Elapsed time: " + TimeToStr(TimeInterval / 1000, TIME_SECONDS) + "\n";
  Str = Str + "Remaining time: " + TimeToStr(1.0 * (Amount - Count) * TimeInterval / (1000 * Count), TIME_SECONDS);

  Comment(Str);

  return;
}

void init()
{
  AmountSymbols = SymbolsList(SymbolsAll);

  ArrayResize(SymbolsDescription, AmountSymbols);

  Amount = AmountSymbols * (AmountSymbols - 1) / 2;

  ArrayResize(Correlations, Amount);
  ArrayResize(StrOut, Amount);

  for (int i = 0; i < AmountSymbols; i++)
    SymbolsDescription[i] = /*SymbolType(SymbolsAll[i]) + "\\" + */SymbolDescription(SymbolsAll[i]);

  return;
}

void deinit()
{
  SaveData("Correlations.txt");

  Comment("");

  return;
}

void SortArrayDOUBLE( double& Array[], int& Positions[], int Increase = MODE_ASCEND )
{
  int i, Size = ArraySize(Array);

  ArrayResize(Vector1, Size);
  ArrayResize(Positions, Size);

  for (i = 0; i < Size; i++)
  {
    Vector1[i][0] = Array[i];
    Vector1[i][1] = i;
  }

  ArraySort(Vector1, WHOLE_ARRAY, 0, Increase);

  for (i = 0; i < Size; i++)
    Positions[i] = Vector1[i][1];

  return;
}

void SaveData( string FileName )
{
  int Positions[];
  int handle = FileOpen(FileName, FILE_CSV|FILE_WRITE);
  int Len = StringLen(DoubleToStr(Amount, 0));

  Comment(WindowExpertName() + " (StartTime = " + TimeToStr(StartTime) + ":\nSaving data...");

  if (Rank)
    FileWrite(handle, "Spearman's Rank Correlations:");
  else
    FileWrite(handle, "Pearson's Correlations:");

  SortArrayDOUBLE(Correlations, Positions, MODE_DESCEND);

  for (int i = 0; i < Amount; i++)
    FileWrite(handle, StrNumToLen(i + 1, Len) + ". " + StrOut[Positions[i]]);

  FileClose(handle);

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

void start()
{
  int i, j, Start, Count = 0;
  double Correlation;
  int CurrentTime, PrevTime;
  int BeginTime, EndTime;
  int Len = StringLen(DoubleToStr(Amount, 0));

  Start = GetTickCount();

  for (i = 0; i < AmountSymbols - 1; i++)
  {
    Symbols[0] = SymbolsAll[i];

    for (j = i + 1; j < AmountSymbols; j++)
    {
      Symbols[1] = SymbolsAll[j];

      RefreshRates();

      BeginTime = GetStartTime(StartTime);
      EndTime = GetData(BeginTime);

      Correlations[Count] = GetCorr();
      StrOut[Count] = "Corr = " + DoubleToStr(Correlations[Count], 4) + ", " + Symbols[0] + " - " + Symbols[1] +
                      ", bars = " + MatrixRows + " (" + TimeToStr(BeginTime) + " - " + TimeToStr(EndTime) +
                      "), " + SymbolsDescription[i] + " - " + SymbolsDescription[j];

      Print(StrNumToLen(Count + 1, Len) + "/" + Amount + ": " + StrOut[Count]);


      Correlations[Count] = MathAbs(Correlations[Count]);

      Count++;

      CurrentTime = GetTickCount();

      if ((CurrentTime - PrevTime > 1000) || (CurrentTime - PrevTime < -1000))
      {
        PrevTime = CurrentTime;

        SetComment(CurrentTime - Start, Count);
      }

      if (IsStopped())
      {
        Amount = Count;
        ArrayResize(Correlations, Amount);

        return;
      }
    }
  }

  return;
}