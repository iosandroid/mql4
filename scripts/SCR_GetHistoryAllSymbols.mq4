//https://www.mql5.com/ru/code/9888
#import "user32.dll"
  int PostMessageA( int hWnd, int Msg, int wParam, int lParam );
  int SetWindowTextA( int hWnd, string lpString );
  int GetDlgItem( int hDlg, int nIDDlgItem );
#import

#define WM_KEYDOWN 0x0100
#define WM_COMMAND 0x0111

#define VK_RETURN 0x0D
#define VK_ESCAPE 0x1B
#define VK_HOME   0x24

#define STR_LENGTH 30
#define PAUSE 200

extern int Pause = 5; // Time (sec.) for one symbol history download (FastMethod = TRUE)
extern string period = "M1";
extern bool FastMethod = FALSE; // Fast - some problems...

string Symbols[];
int AmountSymbols;

string NameStartSymbol;
string NameCurrentSymbol;

void InitString( int hwnd )
{
 PostMessageA(hwnd, WM_KEYDOWN, VK_RETURN, 0);
 Sleep(PAUSE); // ждем инициализацию

 PostMessageA(GetDlgItem(hwnd, 0x45A), WM_KEYDOWN, VK_ESCAPE, 0);
 Sleep(PAUSE);

 return;
}

//Активирует строку Str в строке быстрой навигации hwnd-чарта
// NB: При изменении символа или таймфрэйма
// требуется отсутствие запущенного скрипта на hwnd-чарте!
void ActivateString( int hwnd, string Str )
{
  static string StrTmp = "123456789012345678901234567890";

  hwnd = GetDlgItem(hwnd, 0x45A);
  SetWindowTextA(hwnd, Str);
  Sleep(PAUSE);

  while (!IsStopped())
  {
    PostMessageA(hwnd, WM_KEYDOWN, VK_RETURN, 0);

    Sleep(PAUSE);
  }

  return;
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

int GetStartSymbolPos()
{
  int Pos;

  if (!GlobalVariableCheck(NameStartSymbol))
  {
    Alert(WindowExpertName() + ": Start!");

    InitString(WindowHandle(Symbol(), Period()));

    if (FastMethod)
    {
      for (Pos = 0; Pos < AmountSymbols; Pos++)
        CreateHST(Symbols[Pos]);

      Sleep(Pause);
    }

    Pos = 0;

    while (Symbols[Pos] != Symbol())
      Pos++;

    GlobalVariableSet(NameStartSymbol, Pos);
    GlobalVariableSet(NameCurrentSymbol, 0);
  }
  else
    Pos = GlobalVariableGet(NameStartSymbol);

  return(Pos);
}

int GetCurrentSymbolPos()
{
  int Pos = GlobalVariableGet(NameCurrentSymbol);

  return(Pos);
}

bool CreateHST( string Symb )
{
  int Tmp[15];
  int Prd = GetPeriod(period);
  int handle = FileOpenHistory(Symb + Prd + ".hst", FILE_BIN|FILE_READ|FILE_WRITE);

  if (FileSize(handle) > 0)
  {
    if (FileSize(handle) > 148)
    {
      FileSeek(handle, 148, SEEK_SET);

      if (FileReadInteger(handle) == 0)
      {
        FileClose(handle);

        return;
      }

      FileSeek(handle, -44, SEEK_END);

      if (FileReadInteger(handle) == 0)
      {
        FileClose(handle);

        return;
      }

      FileSeek(handle, 0, SEEK_END);
    }
  }
  else
  {
    FileWriteInteger(handle, 400);
    FileWriteString(handle, "Created by " + WindowExpertName(), 64);
    FileWriteString(handle, Symb, 12);
    FileWriteInteger(handle, Prd);
    FileWriteInteger(handle, MarketInfo(Symb, MODE_DIGITS));
    FileWriteArray(handle, Tmp, 0, 15);
  }

  FileWriteInteger(handle, 0);

  for (int i = 0; i < 5; i++)
    FileWriteDouble(handle, 1);

  FileClose(handle);

  return(TRUE);
}

#define AMOUNT_PERIODS 9

int GetPeriod( string& period )
{
  static string PeriodsStr[AMOUNT_PERIODS] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN"};
  static int Periods[AMOUNT_PERIODS] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1,
                                        PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};

  for (int i = 0; i < AMOUNT_PERIODS; i++)
    if (period == PeriodsStr[i])
      return(Periods[i]);

  period = PeriodsStr[0];

  return(Periods[0]);
}

void RefreshChart( int hwnd, int Pause )
{
  int Count;
  int PrevBars;

  if (FastMethod)
  {
    Sleep(Pause);

    PostMessageA(hwnd, WM_COMMAND, 33324, 0);
    Sleep(Pause);
  }
  else
  {
    Pause /= PAUSE;
    Count = 0;

    while (!IsStopped())
    {
      PostMessageA(hwnd, WM_KEYDOWN, VK_HOME, 0);
      Sleep(PAUSE);

      RefreshRates();

      if (PrevBars == Bars)
        Count++;
      else
      {
        PrevBars = Bars;
        Count = 0;

        Comment("Bars = " + PrevBars);
      }

      if (Count > Pause)
        break;
    }
  }

  RefreshRates();

  return;
}

void RemoveExpert( int hwnd )
{
  PostMessageA(hwnd, WM_COMMAND, 33050, 0);

  return;
}

void init()
{
  string Str;
  int PosStart, PosCurrent;
  int hwnd = WindowHandle(Symbol(), Period());
  bool NoChangePeriod = (GetPeriod(period) == Period());
  AmountSymbols = SymbolsList(Symbols);

  Pause *= 500;
  NameStartSymbol = WindowExpertName() + "_StartSymbol";
  NameCurrentSymbol = WindowExpertName() + "_CurrentSymbol";

  PosStart = GetStartSymbolPos();
  PosCurrent = GetCurrentSymbolPos();

  if (NoChangePeriod)
  {
    if (PosCurrent == PosStart)
      PosCurrent++;

    RefreshChart(hwnd, Pause);

    GlobalVariableSet(NameCurrentSymbol, PosCurrent + 1);

    Str = WindowExpertName() + ": " + PosCurrent + " /" + AmountSymbols + " " + Symbol() + ", " + period;

    if (FastMethod)
      Str = Str + " - Done. See the journal for details";
    else
      Str = Str + ", " + Bars + " bars";

    Alert(Str);
  }
  else
    PosCurrent = PosStart;

  if (PosCurrent == AmountSymbols)
  {
    GlobalVariableDel(NameStartSymbol);
    GlobalVariableDel(NameCurrentSymbol);

    Alert(WindowExpertName() + ": Stop!");

    RemoveExpert(hwnd);
  }
  else
  {
    if (NoChangePeriod)
      ActivateString(hwnd, Symbols[PosCurrent]);
    else
    {
      ActivateString(hwnd, period);
      Sleep(Pause);
    }
  }

  return;
}

void start()
{
  return;
}