#import "user32.dll"
  int SendMessageA( int hWnd, int Msg, int wParam, int lParam );
  int PostMessageA( int hWnd, int Msg, int wParam, int lParam );
  int GetAncestor( int hwnd, int gaFlags );
  int GetLastActivePopup( int hWnd );
  int GetDlgItem( int hDlg, int nIDDlgItem );

  int CharPrevA( string lpszStart, string lpszCurrent ); // используем для получения адреса строки
  int CharPrevW( int lpszStart[], int lpszCurrent[] );   // используем для получения адреса массива целых чисел
#import

#define TVM_GETNEXTITEM    4362
#define TVM_SELECTITEM     4363
#define TVM_GETITEM        4364
#define TVGN_ROOT          0
#define TVGN_NEXT          1
#define TVGN_CHILD         4
#define TVGN_CARET         9
#define TVIF_TEXT          1

#define LVM_GETITEMCOUNT   4100
#define LVM_GETITEMTEXT    4141

#define BM_CLICK           0x00F5

#define WM_COMMAND         0x0111

#define PAUSE              500

extern string AlertString = "Trade is disabled";
extern string AlertString2 = "pending";
extern int CheckInterval = 5;

string textbuffer="АбвгдежзийклмнопрстуфхцчшщъыьэюяАбвгдежзийклмнопрстуфхцчшщъыьэюяАбвгдежзийклмнопрстуфхцчшщъыьэюяАбвгдежзийклмнопрстуфхцчшщъыьэюяАбвгдежзийклмнопрстуфхцчшщъыьэюяАбвгдежзийклмнопрстуфхцчшщъыьэюяАбвгдежзийклмнопрстуфхцчшщъыьэюяАбвгдежзийклмнопрстуфхцчшщъыьэю";

int GetJournal( int EndTime, string& StrList[] )
{
  int LVITEM[10];
  int LVITEM_address = CharPrevW(LVITEM, LVITEM); // получаем адрес массива
  LVITEM[5] = CharPrevA(textbuffer, textbuffer); // получаем адрес текстового буфера
  LVITEM[6] = 255; // textmask
  int hListView = GetAncestor(WindowHandle(Symbol(), Period()), 3);

  hListView = GetDlgItem(hListView, 0xE81E);
  hListView = GetDlgItem(hListView, 0x51);
  hListView = GetDlgItem(hListView, 0x81B9);

  int ItemsCount = SendMessageA(hListView, LVM_GETITEMCOUNT, 0, 0);

  ArrayResize(StrList, ItemsCount);

  for (int i = 0; i < ItemsCount; i++)
  {
    LVITEM[2] = 0; // subitem

    if (SendMessageA(hListView, LVM_GETITEMTEXT, i, LVITEM_address) == 0)
      continue;

    if (StrToTime(textbuffer) <= EndTime)
    {
      ArrayResize(StrList, i);

      break;
    }

    StrList[i] = textbuffer + " ";

    LVITEM[2] = 1; // subitem

    if (SendMessageA(hListView, LVM_GETITEMTEXT, i, LVITEM_address) == 0)
      continue;

    StrList[i] = StrList[i] + textbuffer;
  }

  return(i);
}

bool SelectAccount( int hTreeView, string Account )
{
  int TVITEM[10];
  int TVITEM_address = CharPrevW(TVITEM, TVITEM);  // получаем адрес массива    // Dll_GetAddressOfInteger(TVITEM);
  int textbuffer_address = CharPrevA(textbuffer, textbuffer); // получаем адрес текстового буфера  // Dll_GetAddressOfString(textbuffer);
  int hRoot = SendMessageA(hTreeView, TVM_GETNEXTITEM, TVGN_ROOT, 0);
  int hGroup = SendMessageA(hTreeView, TVM_GETNEXTITEM, TVGN_CHILD, hRoot);
  int hAccount = SendMessageA(hTreeView, TVM_GETNEXTITEM, TVGN_CHILD, hGroup);

  TVITEM[0] = TVIF_TEXT;
  TVITEM[4] = textbuffer_address;
  TVITEM[5] = 255;

  while (hGroup > 0)
  {
    if (hAccount == 0)
    {
      hGroup = SendMessageA(hTreeView, TVM_GETNEXTITEM, TVGN_NEXT, hGroup);
      hAccount = SendMessageA(hTreeView, TVM_GETNEXTITEM, TVGN_CHILD, hGroup);

      continue;
    }

    TVITEM[1] = hAccount;

    SendMessageA(hTreeView, TVM_GETITEM, 0, TVITEM_address);

    if (textbuffer == Account)
      break;

    hAccount = SendMessageA(hTreeView, TVM_GETNEXTITEM, TVGN_NEXT, hAccount);
  }

  if (hGroup == 0)
    return(FALSE);

  SendMessageA(hTreeView, TVM_SELECTITEM, TVGN_CARET, hAccount);

  return(TRUE);
}

void Login()
{
  int hwnd = GetAncestor(WindowHandle(Symbol(), Period()), 3);
  int hTreeView = GetDlgItem(hwnd, 0xE81C);

  hTreeView = GetDlgItem(hTreeView, 0x52);
  hTreeView = GetDlgItem(hTreeView, 0x8A6F);

  if (!SelectAccount(hTreeView, AccountNumber() + ": " + AccountName()))
    return;

  PostMessageA(hwnd, WM_COMMAND, 0x80EA, 0);

  Sleep(PAUSE);

  hwnd = GetLastActivePopup(hwnd);
  hwnd = GetDlgItem(hwnd, 1);

  PostMessageA(hwnd, BM_CLICK, 0, 0);

  return;
}

void init()
{
  string Journal[];
  int Size, Pause;

  int PrevTime = TimeLocal();

  while (!IsStopped())
  {
    Comment(WindowExpertName() + ": check the log ..." +
            "\nAlertString = " + AlertString);

    Size = GetJournal(PrevTime, Journal);

    if (Size > 0)
      PrevTime = StrToTime(StringSubstr(Journal[0], 0, 19));

    for (int i = 0; i < Size; i++)
      if ((StringFind(Journal[i], AlertString) >= 0) && (StringFind(Journal[i], AlertString2) >= 0))
      {
        Alert(WindowExpertName() + ": from the log - " + Journal[i]);
        Alert(WindowExpertName() + ": Relogin...");

        Login();

        PrevTime = TimeLocal();

        break;
      }

    Pause = CheckInterval * 1000;

    while (Pause > 0)
    {
      Comment(WindowExpertName() + ": to check the log still have " + DoubleToStr(Pause / 1000, 0) + " s." +
              "\nAlertString = " + AlertString + "\nAlertString2 = " + AlertString2);

      Sleep(PAUSE);

      Pause -= PAUSE;
    }
  }

  return;
}

void start()
{
  return;
}