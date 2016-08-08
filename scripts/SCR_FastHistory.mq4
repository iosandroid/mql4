//https://www.mql5.com/ru/code/10472
#property show_inputs

#define MAINSEEK 148
#define BARSIZE 44  // LONG_VALUE + 5 * DOUBLE_VALUE

#define TIME 0
#define OPEN 1
#define LOW 2
#define HIGH 3
#define CLOSE 4
#define VOLUME 5

#define VOLUMES 0
#define OPENBARS 1

#define NEGATIVE -1

extern int Pips = 0;

int PriceData[][6];

int GetHistory()
{
  int Amount = 0, Count = 0;
  int handle = FileOpenHistory(Symbol() + Period() + ".hst", FILE_BIN|FILE_READ);
  int FirstTime = Time[Bars - 1];

  if (handle > 0)
  {
    FileSeek(handle, MAINSEEK, SEEK_SET);
    Count = (FileSize(handle) - MAINSEEK) / BARSIZE;

    ArrayResize(PriceData, Count);
  }

  while (Count > 0)
  {
    PriceData[Amount][TIME] = FileReadInteger(handle);

    if (PriceData[Amount][TIME] >= FirstTime)
      break;

    PriceData[Amount][OPEN] = FileReadDouble(handle) / Point + 0.1;
    PriceData[Amount][LOW] = FileReadDouble(handle) / Point + 0.1;
    PriceData[Amount][HIGH] = FileReadDouble(handle) / Point + 0.1;
    PriceData[Amount][CLOSE] = FileReadDouble(handle) / Point + 0.1;
    PriceData[Amount][VOLUME] = FileReadDouble(handle) + 0.1;

    Amount++;
    Count--;
  }

  if (handle > 0)
    FileClose(handle);

  RefreshRates();

  ArrayResize(PriceData, Amount + Bars);

  Count = Bars - 1;

  while (Count >= 0)
  {
    PriceData[Amount][TIME] = Time[Count];
    PriceData[Amount][OPEN] = Open[Count] / Point + 0.1;
    PriceData[Amount][LOW] = Low[Count] / Point + 0.1;
    PriceData[Amount][HIGH] = High[Count] / Point + 0.1;
    PriceData[Amount][CLOSE] = Close[Count] / Point + 0.1;
    PriceData[Amount][VOLUME] = Volume[Count] + 0.1;

    Amount++;
    Count--;
  }

  return(Amount);
}

bool SaveHistory()
{
  int Tmp[15];
  int Amount = ArrayRange(PriceData, 0);
  int handle = FileOpenHistory(Symbol() + Period() + "_Fast.hst", FILE_BIN|FILE_WRITE);

  if (handle < 0)
    return(FALSE);

  FileWriteInteger(handle, 400);
  FileWriteString(handle, "Created by " + WindowExpertName(), 64);
  FileWriteString(handle, Symbol(), 12);
  FileWriteInteger(handle, Period());
  FileWriteInteger(handle, MarketInfo(Symbol(), MODE_DIGITS));
  FileWriteArray(handle, Tmp, 0, 15);

  for (int i = 0; i < Amount; i++)
    if (PriceData[i][TIME] != NEGATIVE)
    {
      FileWriteInteger(handle, PriceData[i][TIME]);
      FileWriteDouble(handle, NormalizeDouble(PriceData[i][OPEN] * Point, Digits));
      FileWriteDouble(handle, NormalizeDouble(PriceData[i][LOW] * Point, Digits));
      FileWriteDouble(handle, NormalizeDouble(PriceData[i][HIGH] * Point, Digits));
      FileWriteDouble(handle, NormalizeDouble(PriceData[i][CLOSE] * Point, Digits));
      FileWriteDouble(handle, PriceData[i][VOLUME]);
    }

  FileClose(handle);

  return(TRUE);
}

string TransformHistory( int Pips )
{
  int Tmp, NTime, PrevTime = 1;
  int i, Min, Max = 0;
  int POpen, PLow, PHigh, PClose;
  bool FlagUP = TRUE;
  int Amount = ArrayRange(PriceData, 0);
  int PrevSum = 0, NewSum = 0, AmountBars = Amount;

  for (i = 0; i < Amount; i++)
  {
    PLow = PriceData[i][LOW];
    PHigh = PriceData[i][HIGH];

    if (FlagUP)
    {
      if (PHigh > Max)
      {
        Max = PHigh;
        NTime = i;
      }

      if (Max - PLow >= Pips)
      {
        while (PrevTime < NTime)
        {
          PriceData[PrevTime][TIME] = NEGATIVE;

          AmountBars--;
          PrevTime++;
        }

        PrevTime++;

        FlagUP = FALSE;
        Min = PLow;
        NTime = i;
      }
    }
    else // (FlagUP == FALSE)
    {
      if (PLow < Min)
      {
        Min = PLow;
        NTime = i;
      }

      if (PHigh - Min >= Pips)
      {
        while (PrevTime < NTime)
        {
          PriceData[PrevTime][TIME] = NEGATIVE;

          AmountBars--;
          PrevTime++;
        }

        PrevTime++;

        FlagUP = TRUE;
        Max = PHigh;
        NTime = i;
      }
    }
  }

  for (i = 0; i < Amount; i++)
    if (PriceData[i][TIME] != NEGATIVE)
    {
      POpen = PriceData[i][OPEN];
      PLow = PriceData[i][LOW];
      PHigh = PriceData[i][HIGH];
      PClose = PriceData[i][CLOSE];

      if (PHigh == PLow)
        Tmp = 1;
      else if (POpen != PClose)
      {
        if (((POpen == PHigh) && (PClose == PLow)) ||
            ((POpen == PLow) && (PClose == PHigh)))
          Tmp = 2;
        else if ((POpen == PHigh) || (POpen == PLow) ||
                 (PClose == PLow) || (PClose == PHigh))
          Tmp = 3;
        else
          Tmp = 4;
      }
      else if ((POpen == PHigh) || (POpen == PLow))
        Tmp = 3;
      else
        Tmp = 4;

      PrevSum += PriceData[i][VOLUME];
      NewSum += Tmp;

      PriceData[i][VOLUME] = Tmp;
    }

  return("Model \"Every Tick\" is ~" + DoubleToStr((1.0 * PrevSum / NewSum) * Amount / AmountBars, 2) +
         " times faster.\nModel \"Open prices only\" is ~" + DoubleToStr(1.0 * Amount / AmountBars, 2) +
         " times faster.");
}

void start()
{
  string Str;

  GetHistory();

  Str = TransformHistory(Pips);

  SaveHistory();

  Str = Str + "\nFile " + TerminalPath() + "\\history\\";

  if (AccountServer() == "")
    Str = Str + "...";
  else
    Str = Str + AccountServer();

  Str = Str + "\\" + Symbol() + Period() + "_Fast.hst is created.";

  MessageBox(Str);

  return;
}