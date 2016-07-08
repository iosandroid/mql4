//https://www.mql5.com/ru/code/9507

/* NOT extern */ bool AutoScale = TRUE; // On/Off autoscale of charts

#import "user32.dll"
  int PostMessageA( int hWnd, int Msg, int wParam, int lParam );
  int SetWindowTextA( int hWnd, string lpString );
  int GetWindowTextA( int hWnd, string lpString, int nMaxCount );
  int GetWindow( int hWnd, int uCmd );
  int GetParent( int hWnd );
  int GetDlgItem( int hDlg, int nIDDlgItem );
  int RegisterWindowMessageA( string lpString );
  int GetClientRect( int hWnd, int lpRect[] );
#import

#define WM_KEYDOWN 0x0100
#define WM_COMMAND 0x0111

#define GW_HWNDFIRST 0
#define GW_HWNDNEXT 2

#define VK_RETURN 0x0D
#define VK_ESCAPE 0x1B

#define PAUSE 100
#define STR_LENGTH 30

#define MAX_OBJECTS 1000

#define NOLL ""

string ActiveString;
bool ActiveMode;
string MyObjects[MAX_OBJECTS], OldObjects[MAX_OBJECTS];
int AmountOldObjects = 0, AmountMyObjects = 0;
int CountObject = 0;

//Активирует строку Str в строке быстрой навигации hwnd-чарта
// NB: При изменении символа или таймфрэйма
// требуется отсутствие запущенного скрипта на hwnd-чарте!
void ActivateString( int hwnd, string Str )
{
  static string StrTmp = "123456789012345678901234567890";
  
  hwnd = GetDlgItem(hwnd, 0x45A);
  GetWindowTextA(hwnd, StrTmp, STR_LENGTH);

  if (Str != StrTmp)  
  {
    SetWindowTextA(hwnd, Str);
    PostMessageA(hwnd, WM_KEYDOWN, VK_RETURN, 0);
  }
  
  return;
}

// Возвращает хэндл следующего чарта за hwnd-чартом
int NextChart( int hwnd ) 
{
  int handle;
  
  hwnd = GetParent(hwnd);
  handle = GetWindow(hwnd, GW_HWNDNEXT);
  
  if (handle == 0)
    handle = GetWindow(hwnd, GW_HWNDFIRST);
    
  hwnd = GetDlgItem(handle, 0xE900); 
  
  return(hwnd);
}

// Активирует строку Str в строках быстрой навигации
// всех графиков , кроме основного.
// NB: При изменении символа или таймфрэйма
// требуется отсутствие запущенных скриптов!
void ChangeAllCharts( string Str, bool Init )
{
  int hwnd, hwnd_base = WindowHandle(Symbol(), Period());
  
  hwnd = NextChart(hwnd_base);
  
  while (hwnd != hwnd_base)
  {
    if (Init)
    {
      PostMessageA(hwnd, WM_KEYDOWN, VK_RETURN, 0);
      Sleep(PAUSE); // ждем инициализацию
      PostMessageA(GetDlgItem(hwnd, 0x45A), WM_KEYDOWN, VK_ESCAPE, 0);
    }
    else
      ActivateString(hwnd, Str);
      
    hwnd = NextChart(hwnd);
  }
  
  return;
}

bool MyObject( string Name )
{
  if (StringFind(Name, WindowExpertName()) == 0)
    return(TRUE);
    
  return(FALSE);
}

void GetOldAndMyObjects( int Type )
{
  int Pos, Tmp, Length;
  string Name;
  
  Length =  StringLen(WindowExpertName());
  Pos = ObjectsTotal() - 1;
  
  if (ActiveMode)
    while (Pos >= 0)
    {
      Name = ObjectName(Pos);
      
      if (ObjectType(Name) == Type)
      {
        if (MyObject(Name))
        {
          MyObjects[AmountMyObjects] = Name;
          AmountMyObjects++;
        
          GlobalVariableSet(Name, ObjectGet(Name, OBJPROP_TIME1));
        
          Tmp = StrToInteger(StringSubstr(Name, Length));
        
          if (Tmp > CountObject)
            CountObject = Tmp + 1;
        }
        else
        {
          OldObjects[AmountOldObjects] = Name;
          AmountOldObjects++;
        }
      }
    
      Pos--;
    }
  else
    while (Pos >= 0)
    {
      Name = ObjectName(Pos);
    
      if (ObjectType(Name) == Type)
        if (MyObject(Name))
        {
          MyObjects[AmountMyObjects] = Name;
          AmountMyObjects++;
        }
        
      Pos--;
    }
    
  return;
}

bool OldObject( string Name )
{
  int i;
  
  for (i = 0; i < AmountOldObjects; i++)
    if (OldObjects[i] == Name)
      return(TRUE);
      
  return(FALSE);
}

string GetNewObject( int Type )
{
  int Pos;
  string Name;
  
  Pos = ObjectsTotal() - 1;
  
  while (Pos >= 0)
  {
    Name = ObjectName(Pos);
    
    if (ObjectType(Name) == Type)
      if (!MyObject(Name))
        if (!OldObject(Name))
          return(Name);
    
    Pos--;
  }
  
  return(NOLL);
}

void DeleteSomeObjects()
{
  int Pos = 0, Amount = 0;
  string Name;
  
  if (ActiveMode)
    while (Amount < AmountMyObjects)
    {
      Name = MyObjects[Pos];
    
      if (Name != NOLL)
      {
        if (ObjectFind(Name) < 0)
        {
          MyObjects[Pos] = NOLL;
          AmountMyObjects--;
        
          GlobalVariableDel(Name);
        }
        else
          Amount++;
      }
    
      Pos++;
    }
  else
    while (Amount < AmountMyObjects)
    {
      Name = MyObjects[Pos];

      if (Name != NOLL)
      {
        if (!GlobalVariableCheck(Name))
        {
          ObjectDelete(Name);
          WindowRedraw();
          MyObjects[Pos] = NOLL;
          AmountMyObjects--;
        }
        else
          Amount++;
      }
      
      Pos++;
    }
  
  return;
}

int GetNOLLPosition()
{
  int Pos = 0;
  
  while (Pos < AmountMyObjects)
  {
    if (MyObjects[Pos] == NOLL)
      break;
    
    Pos++;
  }
  
  return(Pos);
}

void AddMyObject( string Name )
{
  int Pos, CoordX;
  
  CoordX = ObjectGet(Name, OBJPROP_TIME1);
  ObjectDelete(Name);

  Name = WindowExpertName() + CountObject;
  
  ObjectCreate(Name, OBJ_VLINE, 0, CoordX, 0);
  WindowRedraw();

  GlobalVariableSet(Name, CoordX);
  
  Pos = GetNOLLPosition();
  MyObjects[Pos] = Name;
  AmountMyObjects++;
  
  CountObject++;
  
  return;
}

void DeleteGlobalVariables()
{
  string Name;
  int Pos = GlobalVariablesTotal() - 1;
  

  while (Pos >= 0)
  {
    Name = GlobalVariableName(Pos);
    
    if (MyObject(Name))
      GlobalVariableDel(Name);
    
    Pos--;
  }
  
  return;
}

void CheckChanges()
{
  int CoordNew, CoordPrev, Pos = 0, Amount = 0;
  string Name;

  DeleteSomeObjects();

  if (ActiveMode)
    while (Amount < AmountMyObjects)
    {
      Name = MyObjects[Pos];
      
      if (MyObjects[Pos] != NOLL)
      {
        CoordNew = ObjectGet(Name, OBJPROP_TIME1);
        CoordPrev = GlobalVariableGet(Name);
    
        if (CoordNew != CoordPrev)
          GlobalVariableSet(Name, CoordNew);
          
        Amount++;
      }
      
      Pos++;
    }
  else
  {
    Pos = GlobalVariablesTotal() - 1;
    
    while (Pos >= 0)
    {
      Name = GlobalVariableName(Pos);
      
      if (Name != ActiveString)
        if (MyObject(Name))
        {
          CoordNew = GlobalVariableGet(Name);
          
          if (ObjectFind(Name) < 0)
          {
            ObjectCreate(Name, OBJ_VLINE, 0, CoordNew, 0);
            WindowRedraw();

            Amount = GetNOLLPosition();
            MyObjects[Amount] = Name;
            AmountMyObjects++;
          }
          else
          {
            CoordPrev = ObjectGet(Name, OBJPROP_TIME1);
            
            if (CoordNew != CoordPrev)
            {
              ObjectMove(Name, 0, CoordNew, 0);
              WindowRedraw();
            }
          }
        }
        
      Pos--;
    }
  }
  
  return;
}

void RunMySelf()
{
  int hwnd, hwnd_base = WindowHandle(Symbol(), Period());
  int MT4InternalMsg = RegisterWindowMessageA("MetaTrader4_Internal_Message");
  
  hwnd = NextChart(hwnd_base);
  
  while (hwnd != hwnd_base)
  {
    PostMessageA(hwnd, MT4InternalMsg, 17, 0); 
      
    hwnd = NextChart(hwnd);
  }
  
  return;
}

int GetScale()
{
  static int Rect[4], Res;
  int hwnd = WindowHandle(Symbol(), Period());
  int PrevRect = -1, PrevBars, Tmp;

// Check of changes of the sizes of a window of the chart
  while ((PrevRect != Rect[2]) || (PrevBars != Tmp))
  {
    PrevRect = Rect[2];
    PrevBars = Tmp;
    Tmp = WindowBarsPerChart();
    GetClientRect(hwnd, Rect);
  }

  if (PrevBars > 0)
  {
    Res = 1;
    PrevRect -= 44;
    
    while(PrevBars <= PrevRect)
    {
      PrevBars += PrevBars;
      Res += Res;
    }
  }
  
  return(Res);
}

void CheckScales()
{
  int hwnd, PrevScale, NewScale;
  
  if (ActiveMode)
  {
    NewScale = GetScale();
    PrevScale = GlobalVariableGet(ActiveString);
  
    if (NewScale != PrevScale)
      GlobalVariableSet(ActiveString, NewScale);
  }
  else
  {
    NewScale = GlobalVariableGet(ActiveString);
    PrevScale = GetScale();
    hwnd = WindowHandle(Symbol(), Period());
    
    while (NewScale != PrevScale)
    {
      if (NewScale > PrevScale)
        PostMessageA(hwnd, WM_COMMAND, 33025, 0);
      else
        PostMessageA(hwnd, WM_COMMAND, 33026, 0);

      Sleep(PAUSE);
    
      NewScale = GlobalVariableGet(ActiveString);
      PrevScale = GetScale();
    }
  }
    
  return;
}

void ActiveModeFunc()
{
  string Name;
  
  Comment("Script " + WindowExpertName() + " is executing (ACTIVE)!");
  
  ChangeAllCharts("", TRUE);

  DeleteGlobalVariables();
  GetOldAndMyObjects(OBJ_VLINE);
  GlobalVariableSet(ActiveString, GetScale());

  RunMySelf();
  
  while (!IsStopped())
  {
    RefreshRates(); // обязательно!
    ChangeAllCharts(TimeToStr(Time[WindowFirstVisibleBar()]), FALSE);
    
    if (AutoScale)
      CheckScales();

    Name = GetNewObject(OBJ_VLINE);

    if (Name != NOLL)
      AddMyObject(Name);
      
    CheckChanges();
    
    Sleep(PAUSE);
  }

  ChangeAllCharts("", FALSE);
  
  return;
}

void PassiveModeFunc()
{
  GetOldAndMyObjects(OBJ_VLINE);
  
  while (IsStarted() && (!IsStopped()))
  {
    if (AutoScale)
      CheckScales();

    CheckChanges();
    
    Sleep(PAUSE);
  }
  
  return;
}

bool IsStarted()
{ 
  return(GlobalVariableCheck(ActiveString));
}

void deinit()
{
  if (ActiveMode)
  {
    DeleteGlobalVariables();
    Comment("");
  }
  
  return;
}

void start()
{
  ActiveString = WindowExpertName() + "Run"; 
  ActiveMode = !IsStarted();
  
  if (ActiveMode)
    ActiveModeFunc();
  else
    PassiveModeFunc();
  
  return;
}