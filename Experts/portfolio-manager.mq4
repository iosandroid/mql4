//+------------------------------------------------------------------+
//| Portfolio Manager                                                |
//| Expert for Portfolio Modeller indicator                          |
//+------------------------------------------------------------------+
//| Idea and coding by transcendreamer                               |
//+------------------------------------------------------------------+
#property copyright "Portfolio Manager - by transcendreamer"
#property description "Expert for Portfolio Modeller indicator"
#property strict
//---
extern string Portfolio_Name="";
extern int    Magic_Number=0;
extern double Stopout_Value=0;
extern double Target_Value=0;
extern int    Lots_Digits=2;
extern double Multiplicator=1.5;
extern bool   Show_Positions=true;
extern color  Text_Color=Navy;
extern string Formula_Delimiter="=";
extern int    Retry_Delay=500;
extern int    Hotkey_Sell=219;
extern int    Hotkey_Buy=221;
extern int    Hotkey_Close=220;
extern int    Hotkey_Trans=191;
//---
bool error;
int window;
long chart;
string portfolio_id,window_id;
int total;
string SYMBOLS[];
double LOTS[],VOLUMES[];
double previous,current,profit,volume;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
void OnInit()
  {
//---
   error=false;
   previous=0;
   chart=ChartID();
   window=ChartWindowFind(0,"Portfolio Modeller");
   window_id=(string)window;
   portfolio_id=(string)chart+"-"+window_id;
//---
   if(window==-1) { error=true; MessageBox("Portfolio indicator not found!","",MB_ICONERROR); return; }
   if(Portfolio_Name=="") { error=true; MessageBox("Empty portfolio name!","",MB_ICONERROR); return; }
//---
   PlaceButton("Button_Sell","SELL",CORNER_RIGHT_UPPER,156,2,50,13,"Small fonts",7,Text_Color,Gray);
   PlaceButton("Button_Buy","BUY",CORNER_RIGHT_UPPER,104,2,50,13,"Small fonts",7,Text_Color,Gray);
   PlaceButton("Button_Close","CLOSE",CORNER_RIGHT_UPPER,52,2,50,13,"Small fonts",7,Text_Color,Gray);
   PlaceButton("Button_Trans","TRANS",CORNER_RIGHT_UPPER,208,2,50,13,"Small fonts",7,Text_Color,Gray);
//---
   if(StringFind(Portfolio_Name,"CAKE")!=-1) BakeCake();
//---
   OnTick();
//---
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int n=ObjectsTotal(); n>=1; n--)
     {
      string name=ObjectName(n-1);
      if(ObjectFind(name)!=window) continue;
      if(StringFind(name,"Status-line-"+Portfolio_Name)!=-1) ObjectDelete(name);
      if(StringFind(name,"Stopout-"+Portfolio_Name)!=-1) ObjectDelete(name);
      if(StringFind(name,"Target-"+Portfolio_Name)!=-1) ObjectDelete(name);
      if(StringFind(name,"Breakeven-"+Portfolio_Name)!=-1) ObjectDelete(name);
     }
   ObjectDelete("Button_Sell");
   ObjectDelete("Button_Buy");
   ObjectDelete("Button_Close");
   ObjectDelete("Button_Trans");
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
//---
   if(error) return;
//---
   if(id==CHARTEVENT_OBJECT_CLICK)
     {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      if(sparam=="Button_Buy") { DoOpen(1,false); UpdateStatus(); }
      if(sparam=="Button_Sell") { DoOpen(-1,false); UpdateStatus(); }
      if(sparam=="Button_Close") { DoClose(false); UpdateStatus(); }
      if(sparam=="Button_Trans") { DoTrans(volume,false); UpdateStatus(); }
     }
//---
   if(id==CHARTEVENT_KEYDOWN)
     {
      if(int(lparam)==Hotkey_Buy) { DoOpen(1,false); UpdateStatus(); }
      if(int(lparam)==Hotkey_Sell) { DoOpen(-1,false); UpdateStatus(); }
      if(int(lparam)==Hotkey_Close) { DoClose(false); UpdateStatus(); }
      if(int(lparam)==Hotkey_Trans) { DoTrans(volume,false); UpdateStatus(); }
     }
//---
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(error) return;
   UpdateStatus();
   Monitoring();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateStatus()
  {
//---
   current=GlobalVariableGet("Portfolio-"+portfolio_id);
   volume=(double)GlobalVariableGet("Volume-"+Portfolio_Name);
   ReadScreenFormula();
//---
   profit=0;
   for(int n=OrdersTotal(); n>=1; n--)
     {
      bool select=OrderSelect(n-1,SELECT_BY_POS,MODE_TRADES);
      if(!select) continue;
      if(StringFind(OrderComment(),Portfolio_Name,0)==-1) continue;
      profit+=OrderProfit()+OrderCommission()+OrderSwap();
     }
//---
   string text=Portfolio_Name+"   "+"Volume: "+DoubleToString(volume,2)+"   ";
   text+="Profit: "+DoubleToString(profit,2)+" "+AccountCurrency();
   PlaceLabel("Status-line-"+Portfolio_Name+"-A",220,2,CORNER_RIGHT_UPPER,text,Text_Color,"Tahoma",8);
//---
   if(!Show_Positions) return;
//---
   if(volume!=0 && profit!=0)
     {
      if(true)
        {
         ObjectDelete("Breakeven-"+Portfolio_Name);
         double breakeven=NormalizeDouble((current-profit/volume),2);
         PlaceHorizontal("Breakeven-"+Portfolio_Name,breakeven,Green,STYLE_DASHDOTDOT);
        }
      if(Stopout_Value!=0)
        {
         ObjectDelete("Stopout-"+Portfolio_Name);
         double stopout=NormalizeDouble(current-(Stopout_Value+profit)/volume,2);
         PlaceHorizontal("Stopout-"+Portfolio_Name,stopout,Green,STYLE_DASHDOTDOT);
        }
      if(Target_Value!=0)
        {
         ObjectDelete("Target-"+Portfolio_Name);
         double target=NormalizeDouble(current+(Target_Value-profit)/volume,2);
         PlaceHorizontal("Target-"+Portfolio_Name,target,Green,STYLE_DASHDOTDOT);
        }
     }
   else
     {
      ObjectDelete("Breakeven-"+Portfolio_Name);
      ObjectDelete("Stopout-"+Portfolio_Name);
      ObjectDelete("Target-"+Portfolio_Name);
     }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Monitoring()
  {
//---
   if(profit<=-Stopout_Value && Stopout_Value!=0)
     {
      Print("Stopout triggered...");
      DoClose(true);
      UpdateStatus();
     }
//---
   if(profit>=Target_Value && Target_Value!=0)
     {
      Print("Target triggered...");
      DoClose(true);
      UpdateStatus();
     }
//---
   if(current==EMPTY_VALUE) return;
   if(previous==0) { previous=current; return; }
//---
   for(int n=ObjectsTotal(); n>=1; n--)
     {
      string name=ObjectName(n-1);
      if(ObjectFind(name)!=window) continue;
      string text=ObjectDescription(name);
      bool type_buy=(StringFind(text,"BUY")!=-1);
      bool type_sell=(StringFind(text,"SELL")!=-1);
      bool type_close=(StringFind(text,"CLOSE")!=-1);
      bool type_upper=(StringFind(text,"REVERSE UP")!=-1);
      bool type_lower=(StringFind(text,"REVERSE DOWN")!=-1);
      bool type_alert=(StringFind(text,"ALERT")!=-1);
      //---
      double op_volume=0;
      int length=StringLen(text);
      int index=StringFind(text,":");
      if(index==-1) op_volume=1;
      else op_volume=StrToDouble(StringSubstr(text,index+1,length-index-1));
      //---
      double trigger=0;
      if(ObjectType(name)==OBJ_TREND) trigger=NormalizeDouble(ObjectGetValueByShift(name,0),2);
      if(ObjectType(name)==OBJ_HLINE) trigger=NormalizeDouble(ObjectGet(name,OBJPROP_PRICE1),2);
      if(trigger==0) continue;
      //---
      bool cross_up = (previous<trigger && current>=trigger);
      bool cross_dn = (previous>trigger && current<=trigger);
      bool crossing = cross_dn || cross_up;
      //---
      if(type_buy && crossing)
        {
         Print("Crossing triggered: BUY "+string(op_volume));
         if(op_volume==1) DoOpen(1,true);
         else DoTrans(volume+op_volume,true);
         ObjectSetText(name,"LONG:"+string(op_volume));
         UpdateStatus();
        }
      //---
      if(type_sell && crossing)
        {
         Print("Crossing triggered: SELL "+string(op_volume));
         if(op_volume==1) DoOpen(-1,true);
         else DoTrans(volume-op_volume,true);
         ObjectSetText(name,"SHORT:"+string(op_volume));
         UpdateStatus();
        }
      //---
      if(type_upper && cross_up)
        {
         Print("Crossing triggered: REVERSE UP");
         if(volume==0) DoOpen(1,true);
         if(volume<0) DoTrans(-volume*Multiplicator,true);
         UpdateStatus();
        }
      //---
      if(type_lower && cross_dn)
        {
         Print("Crossing triggered: REVERSE DOWN");
         if(volume==0) DoOpen(-1,true);
         if(volume>0) DoTrans(-volume*Multiplicator,true);
         UpdateStatus();
        }
      //---
      if(type_close && profit!=0 && crossing)
        {
         Print("Crossing triggered: CLOSE");
         DoClose(true);
         ObjectSetText(name,"EXIT");
         UpdateStatus();
        }
      //---
      if(type_alert && crossing)
        {
         Print("Crossing triggered: ALERT");
         Alert("Alert level triggered: "+DoubleToString(trigger,2));
         ObjectSetText(name,"LEVEL");
         UpdateStatus();
        }
     }
//---
   previous=current;
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DoTrans(double factor,bool automatic)
  {
//---
   ReadScreenFormula();
//---
   if(!automatic)
     {
      string text="Transformating portfolio: "+Portfolio_Name;
      if(MessageBox(text,"",MB_OKCANCEL|MB_ICONINFORMATION)==IDCANCEL) return;
     }
//---
   for(int i=0; i<total; i++)
     {
      double sum_lots=0;
      for(int n=OrdersTotal(); n>=1; n--)
        {
         bool select=OrderSelect(n-1,SELECT_BY_POS,MODE_TRADES);
         if(!select) continue;
         if(StringFind(OrderComment(),Portfolio_Name,0)==-1) continue;
         if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
         if(OrderSymbol()!=SYMBOLS[i]) continue;
         if(OrderType()==OP_BUY) sum_lots+=OrderLots();
         if(OrderType()==OP_SELL) sum_lots-=OrderLots();
        }
      //---
      double new_lot=NormalizeDouble(factor*LOTS[i],Lots_Digits);
      double delta=NormalizeDouble(new_lot-sum_lots,Lots_Digits);
      if(delta==0) continue;
      //---
      for(int n=OrdersTotal(); n>=1; n--)
        {
         bool select=OrderSelect(n-1,SELECT_BY_POS,MODE_TRADES);
         if(!select) continue;
         if(StringFind(OrderComment(),Portfolio_Name,0)==-1) continue;
         if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
         if(OrderSymbol()!=SYMBOLS[i]) continue;
         if(OrderType()==OP_BUY && delta>0) continue;
         if(OrderType()==OP_SELL && delta<0) continue;
         if(OrderLots()>MathAbs(delta)) continue;
         while(true)
           {
            bool check=false;
            double price_ask=MarketInfo(OrderSymbol(),MODE_ASK);
            double price_bid=MarketInfo(OrderSymbol(),MODE_BID);
            if(OrderType()==OP_BUY) check=OrderClose(OrderTicket(),OrderLots(),price_bid,0);
            if(OrderType()==OP_SELL) check=OrderClose(OrderTicket(),OrderLots(),price_ask,0);
            if(check) break;
            string message="Trading error! - "+ErrorDescription(GetLastError());
            if(!automatic) if(MessageBox(message,"",MB_RETRYCANCEL|MB_ICONERROR)==IDCANCEL) return;
            else { Print(message); Alert(message); Sleep(Retry_Delay); }
            RefreshRates();
            if(IsStopped()) break;
           }
         if(delta>0) delta-=OrderLots();
         if(delta<0) delta+=OrderLots();
        }
      //---
      while(true)
        {
         int ticket=-1;
         double price_ask=MarketInfo(SYMBOLS[i],MODE_ASK);
         double price_bid=MarketInfo(SYMBOLS[i],MODE_BID);
         if(delta>0) ticket=OrderSend(SYMBOLS[i],OP_BUY,MathAbs(delta),price_ask,0,0,0,Portfolio_Name+" ",Magic_Number);
         if(delta<0) ticket=OrderSend(SYMBOLS[i],OP_SELL,MathAbs(delta),price_bid,0,0,0,Portfolio_Name+" ",Magic_Number);
         if(delta==0) break;
         if(ticket!=-1) break;
         string message="Trading error! - "+ErrorDescription(GetLastError());
         if(!automatic) if(MessageBox(message,"",MB_RETRYCANCEL|MB_ICONERROR)==IDCANCEL) return;
         else { Print(message); Alert(message); Sleep(Retry_Delay); }
         RefreshRates();
         if(IsStopped()) break;
        }
     }
//---
   for(int n=OrdersTotal(); n>=1; n--)
     {
      bool select=OrderSelect(n-1,SELECT_BY_POS,MODE_TRADES);
      if(!select) continue;
      if(StringFind(OrderComment(),Portfolio_Name,0)==-1) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      bool found=false;
      for(int i=0; i<total; i++) if(SYMBOLS[i]==OrderSymbol()) found=true;
      if(found) continue;
      while(true)
        {
         bool check=false;
         double price_ask=MarketInfo(OrderSymbol(),MODE_ASK);
         double price_bid=MarketInfo(OrderSymbol(),MODE_BID);
         if(OrderType()==OP_BUY) check=OrderClose(OrderTicket(),OrderLots(),price_bid,0);
         if(OrderType()==OP_SELL) check=OrderClose(OrderTicket(),OrderLots(),price_ask,0);
         if(check) break;
         string message="Trading error! - "+ErrorDescription(GetLastError());
         if(!automatic) if(MessageBox(message,"",MB_RETRYCANCEL|MB_ICONERROR)==IDCANCEL) return;
         else { Print(message); Alert(message); Sleep(Retry_Delay); }
         RefreshRates();
         if(IsStopped()) break;
        }
     }
//---
   volume=factor;
   GlobalVariableSet("Volume-"+Portfolio_Name,factor);
//---
   current=GlobalVariableGet("Portfolio-"+portfolio_id);
   string text="Portfolio "+Portfolio_Name+" transformed at "+DoubleToStr(current,2);
   if(!automatic) MessageBox(text,""); else Print(text);
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DoOpen(int direction,bool automatic)
  {
//---
   ReadScreenFormula();
//---
   if(!automatic)
     {
      string text;
      if(direction==1) text="Opening LONG portfolio: " + Portfolio_Name;
      if(direction==-1) text ="Opening SHORT portfolio: " + Portfolio_Name;
      if(MessageBox(text,"",MB_OKCANCEL|MB_ICONINFORMATION)==IDCANCEL) return;
     }
//---
   for(int i=0; i<total; i++)
      while(true)
        {
         int ticket=-1;
         double lot=MathAbs(LOTS[i]);
         double price_ask=MarketInfo(SYMBOLS[i],MODE_ASK);
         double price_bid=MarketInfo(SYMBOLS[i],MODE_BID);
         if(direction*LOTS[i]>0) ticket=OrderSend(SYMBOLS[i],OP_BUY,lot,price_ask,0,0,0,Portfolio_Name+" ",Magic_Number);
         if(direction*LOTS[i]<0) ticket=OrderSend(SYMBOLS[i],OP_SELL,lot,price_bid,0,0,0,Portfolio_Name+" ",Magic_Number);
         if(LOTS[i]==0) break;
         if(ticket!=-1) break;
         string message="Trading error! - "+ErrorDescription(GetLastError());
         if(!automatic) if(MessageBox(message,"",MB_RETRYCANCEL|MB_ICONERROR)==IDCANCEL) return;
         else { Print(message); Alert(message); Sleep(Retry_Delay); }
         RefreshRates();
         if(IsStopped()) break;
        }
//---
   volume=GlobalVariableGet("Volume-"+Portfolio_Name);
   GlobalVariableSet("Volume-"+Portfolio_Name,volume+direction);
//---
   string text;
   current=GlobalVariableGet("Portfolio-"+portfolio_id);
   if(direction==1) text = "LONG portfolio " + Portfolio_Name + " opened at " + DoubleToStr(current,2);
   if(direction==-1) text = "SHORT portfolio " + Portfolio_Name + " opened at " + DoubleToStr(current,2);
   if(!automatic) MessageBox(text,""); else Print(text);
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DoClose(bool automatic)
  {
//---
   ReadScreenFormula();
//---
   if(!automatic)
     {
      string text="Closing out portfolio: "+Portfolio_Name;
      if(MessageBox(text,"",MB_OKCANCEL|MB_ICONINFORMATION)==IDCANCEL) return;
     }
//---
   int count=0;
   for(int n=OrdersTotal(); n>=1; n--)
     {
      bool select=OrderSelect(n-1,SELECT_BY_POS,MODE_TRADES);
      if(!select) continue;
      if(StringFind(OrderComment(),Portfolio_Name,0)==-1) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      count++;
      while(true)
        {
         bool check=false;
         double price_ask=MarketInfo(OrderSymbol(),MODE_ASK);
         double price_bid=MarketInfo(OrderSymbol(),MODE_BID);
         if(OrderType()==OP_BUY) check=OrderClose(OrderTicket(),OrderLots(),price_bid,0);
         if(OrderType()==OP_SELL) check=OrderClose(OrderTicket(),OrderLots(),price_ask,0);
         if(check) break;
         string message="Trading error! - "+ErrorDescription(GetLastError());
         if(!automatic) if(MessageBox(message,"",MB_RETRYCANCEL|MB_ICONERROR)==IDCANCEL) return;
         else { Print(message); Alert(message); Sleep(Retry_Delay); }
         RefreshRates();
         if(IsStopped()) break;
        }
     }
//---
   GlobalVariableDel("Volume-"+Portfolio_Name);
   ObjectDelete("Breakeven-"+Portfolio_Name);
   ObjectDelete("Stopout-"+Portfolio_Name);
   ObjectDelete("Target-"+Portfolio_Name);
//---
   string text;
   current=GlobalVariableGet("Portfolio-"+portfolio_id);
   if(count>0) text="Portfolio "+Portfolio_Name+" closed at "+DoubleToStr(current,2);
   else text="No positions for portfolio: "+Portfolio_Name;
   if(!automatic) MessageBox(text,""); else Print(text);
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ReadScreenFormula()
  {
//---
   total=0;
   for(int n=ObjectsTotal(); n>=1; n--)
     {
      string name=ObjectName(n-1);
      if(ObjectFind(0,name)!=window) continue;
      if(StringFind(name,"Formula-label-")==-1) continue;
      total++;
      ArrayResize(SYMBOLS,total);
      ArrayResize(LOTS,total);
      ArrayResize(VOLUMES,total);
      SYMBOLS[total-1]=ObjectGetString(0,name,OBJPROP_TEXT,0);
     }
//---
   for(int i=0; i<total; i++)
     {
      int length=StringLen(SYMBOLS[i]);
      int index=length-1;
      while(index>=0)
        {
         string character=StringSubstr(SYMBOLS[i],index,1);
         if(character==Formula_Delimiter) break;
         if(index==0) break;
         else index--;
        }
      if(index==0) LOTS[i]=1;
      else LOTS[i]=StrToDouble(StringSubstr(SYMBOLS[i],index+1,length-index-1));
      SYMBOLS[i]=StringSubstr(SYMBOLS[i],0,index);
     }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PlaceLabel(string name,int x,int y,int corner,string text,int colour,string font,int size)
  {
   ObjectCreate(name,OBJ_LABEL,window,0,0);
   ObjectSet(name,OBJPROP_CORNER,corner);
   ObjectSet(name,OBJPROP_XDISTANCE,x);
   ObjectSet(name,OBJPROP_YDISTANCE,y);
   ObjectSetText(name,text,size,font,colour);
   ObjectSet(name,OBJPROP_SELECTABLE,false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PlaceVertical(string name,datetime time,int colour,int style)
  {
   ObjectCreate(0,name,OBJ_VLINE,window,time,0);
   ObjectSetInteger(0,name,OBJPROP_COLOR,colour);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PlaceHorizontal(string name,double price,int colour,int style)
  {
   ObjectCreate(0,name,OBJ_HLINE,window,0,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,colour);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PlaceButton(string name,string text,int corner,int x,int y,int xsize,int ysize,
                 string font,int fontsize,color colour,color border)
  {
   ObjectCreate(0,name,OBJ_BUTTON,window,0,0);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontsize);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,xsize);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,ysize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,colour);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,border);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BakeCake()
  {
   string text="You are ready to bake a super cake!\n"+
               "Before you proceed please make sure that:\n"+
               "1. your baking device is ON and connected to network adapter\n"+
               "2. your computer and baking device are in the same network\n"+
               "3. you have properly specified program data request in the code\n";
   if(MessageBox(text,"",MB_OKCANCEL|MB_ICONINFORMATION)==IDCANCEL) return;
//---
string cake00="                       (             )                        ";
string cake01="               )      (*)           (*)      (                ";
string cake02="              (*)      |             |      (*)               ";
string cake03="               |      |~|           |~|      |                ";
string cake04="              |~|     | |           | |     |~|               ";
string cake05="              | |     | |           | |     | |               ";
string cake06="             ,| |a@@@@| |@@@@@@@@@@@| |@@@@a| |.              ";
string cake07="        .,a@@@| |@@@@@| |@@@@@@@@@@@| |@@@@@| |@@@@a,.        ";
string cake08="      ,a@@@@@@| |@@@@@@@@@@@@.@@@@@@@@@@@@@@| |@@@@@@@a,      ";
string cake09="     a@@@@@@@@@@@@@@@@@@@@@' . `@@@@@@@@@@@@@@@@@@@@@@@@a     ";
string cake10="     ;`@@@@@@@@@@@@@@@@@@'   .   `@@@@@@@@@@@@@@@@@@@@@';     ";
string cake11="     ;@@@`@@@@@@@@@@@@@'     .     `@@@@@@@@@@@@@@@@'@@@;     ";
string cake12="     ;@@@;,.aaaaaaaaaa       .       aaaaa,,aaaaaaa,;@@@;     ";
string cake13="     ;;@;;;;@@@@@@@@;@      @.@      ;@@@;;;@@@@@@;;;;@@;     ";
string cake14="     ;;;;;;;@@@@;@@;;@    @@ . @@    ;;@;;;;@@;@@@;;;;;;;     ";
string cake15="     ;;;;;;;;@@;;;;;;;  @@   .   @@  ;;;;;;;;;;;@@;;;;@;;     ";
string cake16="     ;;;;;;;;;;;;;;;;;@@     .     @@;;;;;;;;;;;;;;;;@@@;     ";
string cake17="   ,%;;;;;;;;@;;;;;;;;       .       ;;;;;;;;;;;;;;;;@@;;%,   ";
string cake18=" .%%%;;;;;;;@@;;;;;;;;     ,%%%,     ;;;;;;;;;;;;;;;;;;;;%%%, ";
string cake19=".%%%%;;;;;;;@@;;;;;;;;   ,%%%%%%%,   ;;;;;;;;;;;;;;;;;;;;%%%%,";
string cake20="%%%%%`;;;;;;;;;;;;;;;;  %%%%%%%%%%%  ;;;;;;;;;;;;;;;;;;;'%%%%%";
string cake21="%%%%%%%%%`;;;;;;;;;;;;,%%%%%%%%%%%%%,;;;;;;;;;;;;;;;'%%%%%%%%%";
string cake22="`%%%%%%%%%%%%%%,,,,,,,%%%%%%%%%%%%%%%,,,,,,,%%%%%%%%%%%%%%%%%'";
string cake23="  `%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'  ";
string cake24="    `%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'    ";
string cake25="          ^^^^^^^^^^^^^^`,,,,,,,,,'^^^^^^^^^^^^^^^^^          ";
string cake26="                         `%%%%%%%'                            ";
string cake27="                          `%%%%%'                             ";
string cake28="                            %%%                               ";
string cake29="                           %%%%%                              ";
string cake30="                        .,%%%%%%%,.                           ";
string cake31="                   ,%%%%%%%%%%%%%%%%%%%,                      ";
//---                           
PlaceLabel("cake00",100,090,CORNER_RIGHT_UPPER,cake00,Red,"Fixedsys",12);
PlaceLabel("cake01",100,100,CORNER_RIGHT_UPPER,cake01,Red,"Fixedsys",12);
PlaceLabel("cake02",100,110,CORNER_RIGHT_UPPER,cake02,Red,"Fixedsys",12);
PlaceLabel("cake03",100,120,CORNER_RIGHT_UPPER,cake03,Red,"Fixedsys",12);
PlaceLabel("cake04",100,130,CORNER_RIGHT_UPPER,cake04,Red,"Fixedsys",12);
PlaceLabel("cake05",100,140,CORNER_RIGHT_UPPER,cake05,Red,"Fixedsys",12);
PlaceLabel("cake06",100,150,CORNER_RIGHT_UPPER,cake06,Red,"Fixedsys",12);
PlaceLabel("cake07",100,160,CORNER_RIGHT_UPPER,cake07,Red,"Fixedsys",12);
PlaceLabel("cake08",100,170,CORNER_RIGHT_UPPER,cake08,Red,"Fixedsys",12);
PlaceLabel("cake09",100,180,CORNER_RIGHT_UPPER,cake09,Red,"Fixedsys",12);
PlaceLabel("cake10",100,190,CORNER_RIGHT_UPPER,cake10,Red,"Fixedsys",12);
PlaceLabel("cake11",100,190,CORNER_RIGHT_UPPER,cake11,Red,"Fixedsys",12);
PlaceLabel("cake12",100,200,CORNER_RIGHT_UPPER,cake12,Red,"Fixedsys",12);
PlaceLabel("cake13",100,210,CORNER_RIGHT_UPPER,cake13,Red,"Fixedsys",12);
PlaceLabel("cake14",100,220,CORNER_RIGHT_UPPER,cake14,Red,"Fixedsys",12);
PlaceLabel("cake15",100,230,CORNER_RIGHT_UPPER,cake15,Red,"Fixedsys",12);
PlaceLabel("cake16",100,240,CORNER_RIGHT_UPPER,cake16,Red,"Fixedsys",12);
PlaceLabel("cake17",100,250,CORNER_RIGHT_UPPER,cake17,Red,"Fixedsys",12);
PlaceLabel("cake18",100,260,CORNER_RIGHT_UPPER,cake18,Red,"Fixedsys",12);
PlaceLabel("cake19",100,270,CORNER_RIGHT_UPPER,cake19,Red,"Fixedsys",12);
PlaceLabel("cake20",100,280,CORNER_RIGHT_UPPER,cake20,Red,"Fixedsys",12);
PlaceLabel("cake21",100,290,CORNER_RIGHT_UPPER,cake21,Red,"Fixedsys",12);
PlaceLabel("cake22",100,300,CORNER_RIGHT_UPPER,cake22,Red,"Fixedsys",12);
PlaceLabel("cake23",100,310,CORNER_RIGHT_UPPER,cake23,Red,"Fixedsys",12);
PlaceLabel("cake24",100,320,CORNER_RIGHT_UPPER,cake24,Red,"Fixedsys",12);
PlaceLabel("cake25",100,330,CORNER_RIGHT_UPPER,cake25,Red,"Fixedsys",12);
PlaceLabel("cake26",100,340,CORNER_RIGHT_UPPER,cake26,Red,"Fixedsys",12);
PlaceLabel("cake27",100,350,CORNER_RIGHT_UPPER,cake27,Red,"Fixedsys",12);
PlaceLabel("cake28",100,360,CORNER_RIGHT_UPPER,cake28,Red,"Fixedsys",12);
PlaceLabel("cake29",100,370,CORNER_RIGHT_UPPER,cake29,Red,"Fixedsys",12);
PlaceLabel("cake30",100,380,CORNER_RIGHT_UPPER,cake30,Red,"Fixedsys",12);
PlaceLabel("cake31",100,390,CORNER_RIGHT_UPPER,cake31,Red,"Fixedsys",12);
//---
   Alert("Sending web request to device...");
   string header="";
   string address="";
   string referer="";
   int timeout=1000;
   char data[];
//--- Please specify the request data above according to your device model and desired program
   int result=WebRequest("POST",address,header,timeout,data,data,header);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ErrorDescription(int code)
  {
   if(code==ERR_NO_ERROR) return("NO_ERROR");
   if(code==ERR_NO_RESULT) return("NO_RESULT");
   if(code==ERR_COMMON_ERROR) return("COMMON_ERROR");
   if(code==ERR_INVALID_TRADE_PARAMETERS) return("INVALID_TRADE_PARAMETERS");
   if(code==ERR_SERVER_BUSY) return("SERVER_BUSY");
   if(code==ERR_OLD_VERSION) return("OLD_VERSION");
   if(code==ERR_NO_CONNECTION) return("NO_CONNECTION");
   if(code==ERR_NOT_ENOUGH_RIGHTS) return("NOT_ENOUGH_RIGHTS");
   if(code==ERR_TOO_FREQUENT_REQUESTS) return("TOO_FREQUENT_REQUESTS");
   if(code==ERR_MALFUNCTIONAL_TRADE) return("MALFUNCTIONAL_TRADE");
   if(code==ERR_ACCOUNT_DISABLED) return("ACCOUNT_DISABLED");
   if(code==ERR_INVALID_ACCOUNT) return("INVALID_ACCOUNT");
   if(code==ERR_TRADE_TIMEOUT) return("TRADE_TIMEOUT");
   if(code==ERR_INVALID_PRICE) return("INVALID_PRICE");
   if(code==ERR_INVALID_STOPS) return("INVALID_STOPS");
   if(code==ERR_INVALID_TRADE_VOLUME) return("INVALID_TRADE_VOLUME");
   if(code==ERR_MARKET_CLOSED) return("MARKET_CLOSED");
   if(code==ERR_TRADE_DISABLED) return("TRADE_DISABLED");
   if(code==ERR_NOT_ENOUGH_MONEY) return("NOT_ENOUGH_MONEY");
   if(code==ERR_PRICE_CHANGED) return("PRICE_CHANGED");
   if(code==ERR_OFF_QUOTES) return("OFF_QUOTES");
   if(code==ERR_BROKER_BUSY) return("BROKER_BUSY");
   if(code==ERR_REQUOTE) return("REQUOTE");
   if(code==ERR_ORDER_LOCKED) return("ORDER_LOCKED");
   if(code==ERR_LONG_POSITIONS_ONLY_ALLOWED) return("LONG_POSITIONS_ONLY_ALLOWED");
   if(code==ERR_TOO_MANY_REQUESTS) return("TOO_MANY_REQUESTS");
   if(code==ERR_TRADE_MODIFY_DENIED) return("TRADE_MODIFY_DENIED");
   if(code==ERR_TRADE_CONTEXT_BUSY) return("TRADE_CONTEXT_BUSY");
   if(code==ERR_TRADE_EXPIRATION_DENIED) return("TRADE_EXPIRATION_DENIED");
   if(code==ERR_TRADE_TOO_MANY_ORDERS) return("TRADE_TOO_MANY_ORDERS");
   if(code==ERR_TRADE_HEDGE_PROHIBITED) return("TRADE_HEDGE_PROHIBITED");
   if(code==ERR_TRADE_PROHIBITED_BY_FIFO) return("TRADE_PROHIBITED_BY_FIFO");
   if(code==ERR_NO_MQLERROR) return("NO_MQLERROR");
   if(code==ERR_WRONG_FUNCTION_POINTER) return("WRONG_FUNCTION_POINTER");
   if(code==ERR_ARRAY_INDEX_OUT_OF_RANGE) return("ARRAY_INDEX_OUT_OF_RANGE");
   if(code==ERR_NO_MEMORY_FOR_CALL_STACK) return("NO_MEMORY_FOR_CALL_STACK");
   if(code==ERR_RECURSIVE_STACK_OVERFLOW) return("RECURSIVE_STACK_OVERFLOW");
   if(code==ERR_NOT_ENOUGH_STACK_FOR_PARAM) return("NOT_ENOUGH_STACK_FOR_PARAM");
   if(code==ERR_NO_MEMORY_FOR_PARAM_STRING) return("NO_MEMORY_FOR_PARAM_STRING");
   if(code==ERR_NO_MEMORY_FOR_TEMP_STRING) return("NO_MEMORY_FOR_TEMP_STRING");
   if(code==ERR_NOT_INITIALIZED_STRING) return("NOT_INITIALIZED_STRING");
   if(code==ERR_NOT_INITIALIZED_ARRAYSTRING) return("NOT_INITIALIZED_ARRAYSTRING");
   if(code==ERR_NO_MEMORY_FOR_ARRAYSTRING) return("NO_MEMORY_FOR_ARRAYSTRING");
   if(code==ERR_TOO_LONG_STRING) return("TOO_LONG_STRING");
   if(code==ERR_REMAINDER_FROM_ZERO_DIVIDE) return("REMAINDER_FROM_ZERO_DIVIDE");
   if(code==ERR_ZERO_DIVIDE) return("ZERO_DIVIDE");
   if(code==ERR_UNKNOWN_COMMAND) return("UNKNOWN_COMMAND");
   if(code==ERR_WRONG_JUMP) return("WRONG_JUMP");
   if(code==ERR_NOT_INITIALIZED_ARRAY) return("NOT_INITIALIZED_ARRAY");
   if(code==ERR_DLL_CALLS_NOT_ALLOWED) return("DLL_CALLS_NOT_ALLOWED");
   if(code==ERR_CANNOT_LOAD_LIBRARY) return("CANNOT_LOAD_LIBRARY");
   if(code==ERR_CANNOT_CALL_FUNCTION) return("CANNOT_CALL_FUNCTION");
   if(code==ERR_EXTERNAL_CALLS_NOT_ALLOWED) return("EXTERNAL_CALLS_NOT_ALLOWED");
   if(code==ERR_NO_MEMORY_FOR_RETURNED_STR) return("NO_MEMORY_FOR_RETURNED_STR");
   if(code==ERR_SYSTEM_BUSY) return("SYSTEM_BUSY");
   if(code==ERR_DLLFUNC_CRITICALERROR) return("DLLFUNC_CRITICALERROR");
   if(code==ERR_INTERNAL_ERROR) return("INTERNAL_ERROR");
   if(code==ERR_OUT_OF_MEMORY) return("OUT_OF_MEMORY");
   if(code==ERR_INVALID_POINTER) return("INVALID_POINTER");
   if(code==ERR_FORMAT_TOO_MANY_FORMATTERS) return("FORMAT_TOO_MANY_FORMATTERS");
   if(code==ERR_FORMAT_TOO_MANY_PARAMETERS) return("FORMAT_TOO_MANY_PARAMETERS");
   if(code==ERR_ARRAY_INVALID) return("ARRAY_INVALID");
   if(code==ERR_CHART_NOREPLY) return("CHART_NOREPLY");
   if(code==ERR_INVALID_FUNCTION_PARAMSCNT) return("INVALID_FUNCTION_PARAMSCNT");
   if(code==ERR_INVALID_FUNCTION_PARAMVALUE) return("INVALID_FUNCTION_PARAMVALUE");
   if(code==ERR_STRING_FUNCTION_INTERNAL) return("STRING_FUNCTION_INTERNAL");
   if(code==ERR_SOME_ARRAY_ERROR) return("SOME_ARRAY_ERROR");
   if(code==ERR_INCORRECT_SERIESARRAY_USING) return("INCORRECT_SERIESARRAY_USING");
   if(code==ERR_CUSTOM_INDICATOR_ERROR) return("CUSTOM_INDICATOR_ERROR");
   if(code==ERR_INCOMPATIBLE_ARRAYS) return("INCOMPATIBLE_ARRAYS");
   if(code==ERR_GLOBAL_VARIABLES_PROCESSING) return("GLOBAL_VARIABLES_PROCESSING");
   if(code==ERR_GLOBAL_VARIABLE_NOT_FOUND) return("GLOBAL_VARIABLE_NOT_FOUND");
   if(code==ERR_FUNC_NOT_ALLOWED_IN_TESTING) return("FUNC_NOT_ALLOWED_IN_TESTING");
   if(code==ERR_FUNCTION_NOT_CONFIRMED) return("FUNCTION_NOT_CONFIRMED");
   if(code==ERR_SEND_MAIL_ERROR) return("SEND_MAIL_ERROR");
   if(code==ERR_STRING_PARAMETER_EXPECTED) return("STRING_PARAMETER_EXPECTED");
   if(code==ERR_INTEGER_PARAMETER_EXPECTED) return("INTEGER_PARAMETER_EXPECTED");
   if(code==ERR_DOUBLE_PARAMETER_EXPECTED) return("DOUBLE_PARAMETER_EXPECTED");
   if(code==ERR_ARRAY_AS_PARAMETER_EXPECTED) return("ARRAY_AS_PARAMETER_EXPECTED");
   if(code==ERR_HISTORY_WILL_UPDATED) return("HISTORY_WILL_UPDATED");
   if(code==ERR_TRADE_ERROR) return("TRADE_ERROR");
   if(code==ERR_RESOURCE_NOT_FOUND) return("RESOURCE_NOT_FOUND");
   if(code==ERR_RESOURCE_NOT_SUPPORTED) return("RESOURCE_NOT_SUPPORTED");
   if(code==ERR_RESOURCE_DUPLICATED) return("RESOURCE_DUPLICATED");
   if(code==ERR_INDICATOR_CANNOT_INIT) return("INDICATOR_CANNOT_INIT");
   if(code==ERR_END_OF_FILE) return("END_OF_FILE");
   if(code==ERR_SOME_FILE_ERROR) return("SOME_FILE_ERROR");
   if(code==ERR_WRONG_FILE_NAME) return("WRONG_FILE_NAME");
   if(code==ERR_TOO_MANY_OPENED_FILES) return("TOO_MANY_OPENED_FILES");
   if(code==ERR_CANNOT_OPEN_FILE) return("CANNOT_OPEN_FILE");
   if(code==ERR_INCOMPATIBLE_FILEACCESS) return("INCOMPATIBLE_FILEACCESS");
   if(code==ERR_NO_ORDER_SELECTED) return("NO_ORDER_SELECTED");
   if(code==ERR_UNKNOWN_SYMBOL) return("UNKNOWN_SYMBOL");
   if(code==ERR_INVALID_PRICE_PARAM) return("INVALID_PRICE_PARAM");
   if(code==ERR_INVALID_TICKET) return("INVALID_TICKET");
   if(code==ERR_TRADE_NOT_ALLOWED) return("TRADE_NOT_ALLOWED");
   if(code==ERR_LONGS_NOT_ALLOWED) return("LONGS_NOT_ALLOWED");
   if(code==ERR_SHORTS_NOT_ALLOWED) return("SHORTS_NOT_ALLOWED");
   if(code==ERR_TRADE_EXPERT_DISABLED_BY_SERVER) return("TRADE_EXPERT_DISABLED_BY_SERVER");
   if(code==ERR_OBJECT_ALREADY_EXISTS) return("OBJECT_ALREADY_EXISTS");
   if(code==ERR_UNKNOWN_OBJECT_PROPERTY) return("UNKNOWN_OBJECT_PROPERTY");
   if(code==ERR_OBJECT_DOES_NOT_EXIST) return("OBJECT_DOES_NOT_EXIST");
   if(code==ERR_UNKNOWN_OBJECT_TYPE) return("UNKNOWN_OBJECT_TYPE");
   if(code==ERR_NO_OBJECT_NAME) return("NO_OBJECT_NAME");
   if(code==ERR_OBJECT_COORDINATES_ERROR) return("OBJECT_COORDINATES_ERROR");
   if(code==ERR_NO_SPECIFIED_SUBWINDOW) return("NO_SPECIFIED_SUBWINDOW");
   if(code==ERR_SOME_OBJECT_ERROR) return("SOME_OBJECT_ERROR");
   if(code==ERR_CHART_PROP_INVALID) return("CHART_PROP_INVALID");
   if(code==ERR_CHART_NOT_FOUND) return("CHART_NOT_FOUND");
   if(code==ERR_CHARTWINDOW_NOT_FOUND) return("CHARTWINDOW_NOT_FOUND");
   if(code==ERR_CHARTINDICATOR_NOT_FOUND) return("CHARTINDICATOR_NOT_FOUND");
   if(code==ERR_SYMBOL_SELECT) return("SYMBOL_SELECT");
   if(code==ERR_NOTIFICATION_ERROR) return("NOTIFICATION_ERROR");
   if(code==ERR_NOTIFICATION_PARAMETER) return("NOTIFICATION_PARAMETER");
   if(code==ERR_NOTIFICATION_SETTINGS) return("NOTIFICATION_SETTINGS");
   if(code==ERR_NOTIFICATION_TOO_FREQUENT) return("NOTIFICATION_TOO_FREQUENT");
   if(code==ERR_FILE_TOO_MANY_OPENED) return("FILE_TOO_MANY_OPENED");
   if(code==ERR_FILE_WRONG_FILENAME) return("FILE_WRONG_FILENAME");
   if(code==ERR_FILE_TOO_LONG_FILENAME) return("FILE_TOO_LONG_FILENAME");
   if(code==ERR_FILE_CANNOT_OPEN) return("FILE_CANNOT_OPEN");
   if(code==ERR_FILE_BUFFER_ALLOCATION_ERROR) return("FILE_BUFFER_ALLOCATION_ERROR");
   if(code==ERR_FILE_CANNOT_DELETE) return("FILE_CANNOT_DELETE");
   if(code==ERR_FILE_INVALID_HANDLE) return("FILE_INVALID_HANDLE");
   if(code==ERR_FILE_WRONG_HANDLE) return("FILE_WRONG_HANDLE");
   if(code==ERR_FILE_NOT_TOWRITE) return("FILE_NOT_TOWRITE");
   if(code==ERR_FILE_NOT_TOREAD) return("FILE_NOT_TOREAD");
   if(code==ERR_FILE_NOT_BIN) return("FILE_NOT_BIN");
   if(code==ERR_FILE_NOT_TXT) return("FILE_NOT_TXT");
   if(code==ERR_FILE_NOT_TXTORCSV) return("FILE_NOT_TXTORCSV");
   if(code==ERR_FILE_NOT_CSV) return("FILE_NOT_CSV");
   if(code==ERR_FILE_READ_ERROR) return("FILE_READ_ERROR");
   if(code==ERR_FILE_WRITE_ERROR) return("FILE_WRITE_ERROR");
   if(code==ERR_FILE_BIN_STRINGSIZE) return("FILE_BIN_STRINGSIZE");
   if(code==ERR_FILE_INCOMPATIBLE) return("FILE_INCOMPATIBLE");
   if(code==ERR_FILE_IS_DIRECTORY) return("FILE_IS_DIRECTORY");
   if(code==ERR_FILE_NOT_EXIST) return("FILE_NOT_EXIST");
   if(code==ERR_FILE_CANNOT_REWRITE) return("FILE_CANNOT_REWRITE");
   if(code==ERR_FILE_WRONG_DIRECTORYNAME) return("FILE_WRONG_DIRECTORYNAME");
   if(code==ERR_FILE_DIRECTORY_NOT_EXIST) return("FILE_DIRECTORY_NOT_EXIST");
   if(code==ERR_FILE_NOT_DIRECTORY) return("FILE_NOT_DIRECTORY");
   if(code==ERR_FILE_CANNOT_DELETE_DIRECTORY) return("FILE_CANNOT_DELETE_DIRECTORY");
   if(code==ERR_FILE_CANNOT_CLEAN_DIRECTORY) return("FILE_CANNOT_CLEAN_DIRECTORY");
   if(code==ERR_FILE_ARRAYRESIZE_ERROR) return("FILE_ARRAYRESIZE_ERROR");
   if(code==ERR_FILE_STRINGRESIZE_ERROR) return("FILE_STRINGRESIZE_ERROR");
   if(code==ERR_FILE_STRUCT_WITH_OBJECTS) return("FILE_STRUCT_WITH_OBJECTS");
   if(code==ERR_WEBREQUEST_INVALID_ADDRESS) return("WEBREQUEST_INVALID_ADDRESS");
   if(code==ERR_WEBREQUEST_CONNECT_FAILED) return("WEBREQUEST_CONNECT_FAILED");
   if(code==ERR_WEBREQUEST_TIMEOUT) return("WEBREQUEST_TIMEOUT");
   if(code==ERR_WEBREQUEST_REQUEST_FAILED) return("WEBREQUEST_REQUEST_FAILED");
   return("NOT_DEFINED");
  }
//+------------------------------------------------------------------+
