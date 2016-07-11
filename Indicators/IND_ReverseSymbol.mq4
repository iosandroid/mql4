//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2012, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 0

#import "user32.dll"
int PostMessageA(int hWnd,int Msg,int wParam,int lParam);
#import

#define WM_COMMAND 0x0111

#define LB_OFFSET -32
#define BEGIN_OFFSET 148

#define REFRESH_CODE 33324

double open,low,high,close;
int handle,PrevTime;
string SymbolName;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetSymbolName()
  {
   SymbolName=StringSubstr(Symbol(),3,3)+StringSubstr(Symbol(),0,3);

   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool GetBarPrices(int Pos)
  {
   open = 1 / Open[Pos];
   high = 1 / Low[Pos];
   low=1/High[Pos];
   close=1/Close[Pos];

   return(true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void WriteBar(int STime,double SOpen,double SHigh,double SLow,double SClose,double SVolume)
  {
   FileWriteInteger(handle,STime);
   FileWriteDouble(handle,SOpen);
   FileWriteDouble(handle,SLow);
   FileWriteDouble(handle,SHigh);
   FileWriteDouble(handle,SClose);
   FileWriteDouble(handle,SVolume);

   FileFlush(handle);

   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void WriteBars(int Pos)
  {
   Pos--;

   while(Pos>=0)
     {
      GetBarPrices(Pos);
      WriteBar(Time[Pos],open,high,low,close,Volume[Pos]);
      Pos--;
     }

   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyLastBar(int Pos)
  {
   GetBarPrices(Pos);
   FileSeek(handle,LB_OFFSET,SEEK_CUR);

   FileWriteDouble(handle,low);
   FileWriteDouble(handle,high);
   FileWriteDouble(handle,close);
   FileWriteDouble(handle,Volume[Pos]);

   FileFlush(handle);

   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateHandle()
  {
   string FileName;
   int Tmp[15];

   GetSymbolName();
   FileName=SymbolName+Period()+".hst";
   handle=FileOpenHistory(FileName,FILE_BIN|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);

   FileWriteInteger(handle,400);
   FileWriteString(handle,"Created by "+WindowExpertName(),64);
   FileWriteString(handle,SymbolName,12);
   FileWriteInteger(handle,Period());
   FileWriteInteger(handle,Digits);
   FileWriteArray(handle,Tmp,0,15);

   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RefreshChart()
  {
   int hwnd=WindowHandle(SymbolName,Period());
   PostMessageA(hwnd,WM_COMMAND,REFRESH_CODE,0);
   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void init()
  {
   CreateHandle();
   PrevTime=Time[0];
   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void deinit()
  {
   FileClose(handle);
   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void start()
  {
   static int PrevBars=0;
   static int Pos;

   if(PrevTime!=Time[0])
     {
      Pos=iBarShift(Symbol(),Period(),PrevTime);
      ModifyLastBar(Pos);
      WriteBars(Pos);
      PrevTime = Time[0];
      PrevBars = Bars;
     }
   else
     {
      if(PrevBars!=Bars)
        {
         FileSeek(handle,BEGIN_OFFSET,SEEK_SET);
         WriteBars(Bars);
         PrevBars=Bars;
        }
      else
         ModifyLastBar(0);
     }

   RefreshChart();
   return;
  }
//+------------------------------------------------------------------+
