//+------------------------------------------------------------------+
//| Portfolio Modeller                                               |
//| Advanced synthetic optimization and analysis                     |
//+------------------------------------------------------------------+
//| Idea and coding by transcendreamer                               |
//+------------------------------------------------------------------+
#property copyright "Portfolio Modeller - by transcendreamer"
#property description "Advanced synthetic optimization and analysis"
#include <Math\Alglib\alglib.mqh>
#property indicator_separate_window
#property indicator_buffers 9
#property indicator_level1 0
//---
extern string Basis_Formula="";
extern string Offset_Formula="";
extern double Portfolio_Value=0;
enum   METHOD_TYPE {fixed,spread,trend,oscillator,hybrid,root,abs_root,fitting,principal};
extern METHOD_TYPE Model_Type=fixed;
extern double Model_Increment=0;
extern double Model_Amplitude=0;
extern double Model_Cycles=0;
extern double Model_Phase=0;
extern bool   Draw_Model=true;
extern ENUM_TIMEFRAMES Timeframe=PERIOD_D1;
extern datetime Start_Time=D'2012.01.01 00:00';
extern datetime Finish_Time=D'2035.01.01 00:00';
extern bool     Movable_Lines=false;
extern bool     Show_History=true;
extern bool     Show_Forward=true;
enum   CHART_TYPE {single,dual};
extern CHART_TYPE Chart_Type=single;
extern bool   Draw_Histogram=false;
extern bool   Invert_Chart=false;
extern int    Lots_Digits=2;
extern string Chart_Currency="USD";
extern double Commission_Rate=0;
enum   BID_ASK_TYPE {none,longs,shorts};
extern BID_ASK_TYPE Show_Bid_Ask=none;
extern bool   Sync_Last_Bar=false;
extern ENUM_BASE_CORNER Text_Corner=CORNER_LEFT_UPPER;
extern double Chart_Grid_Size=0;
extern color  Basis_Color=Navy;
extern color  Offset_Color=Brown;
extern color  Signal_Color=Red;
extern int    MA_period=0;
enum   CHANNELS_TYPE {empty,bollinger,envelopes,transcendent};
extern CHANNELS_TYPE Channels_Type=empty;
extern double Outer_Channel=2;
extern double Inner_Channel=1;
extern int    RSI_period=0;
extern int    MACD_fast=0;
extern int    MACD_slow=0;
extern string CSV_Export_File="";
extern string CSV_Separator=";";
extern string Formula_Delimiter="=";
extern string FX_prefix="";
extern string FX_postfix="";
//---
bool     error;
long     chart;
int      window;
string   portfolio_id,window_id;
string   SYMBOLS[];
datetime TIMES[];
int      variables,constants,points;
double   opening[],closing[],profit[];
double   EQUITY[][100],MODEL[],ROOTS[],LOTS[];
double   basis[],offset[],MA_data[],RSI_data[],MACD_data[];
double   upper_outer[],upper_inner[],lower_inner[],lower_outer[];
datetime zero_time,limit_time;
int      open_bar,close_bar,start_bar,finish_bar;
double   spread_sum,margin_sum,commission_sum;
double   deviation,range,invert,scale_volume,scale_points;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//---
   error=false;
   window=ChartWindowFind();
   chart=ChartID();
   window_id=(string)window;
   portfolio_id=(string)chart+"-"+window_id;
   if(Invert_Chart) invert=-1; else invert=1;
//---
   IndicatorDigits(2);
   IndicatorShortName("Portfolio Modeller");
   SetIndexLabel(0,"Portfolio Basis");
   SetIndexLabel(1,"Portfolio Offset");
   SetIndexLabel(2,"Portfolio MA");
   SetIndexLabel(3,"Portfolio RSI");
   SetIndexLabel(4,"Portfolio MACD");
   SetIndexLabel(5,"Upper Outer Limit");
   SetIndexLabel(6,"Upper Inner Limit");
   SetIndexLabel(7,"Lower Inner Limit");
   SetIndexLabel(8,"Lower Outer Limit");
//---
   SetIndexBuffer(0,basis);
   SetIndexBuffer(1,offset);
   SetIndexBuffer(2,MA_data);
   SetIndexBuffer(3,RSI_data);
   SetIndexBuffer(4,MACD_data);
   SetIndexBuffer(5,upper_outer);
   SetIndexBuffer(6,upper_inner);
   SetIndexBuffer(7,lower_inner);
   SetIndexBuffer(8,lower_outer);
//---
   ENUM_INDEXBUFFER_TYPE main_style=DRAW_LINE;
   if(Draw_Histogram && Chart_Type==single) main_style=DRAW_HISTOGRAM;
   SetIndexStyle(0,main_style,STYLE_SOLID,1,Basis_Color);
   SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,1,Offset_Color);
   SetIndexStyle(2,DRAW_LINE,STYLE_SOLID,1,Signal_Color);
   SetIndexStyle(3,DRAW_LINE,STYLE_SOLID,1,Signal_Color);
   SetIndexStyle(4,DRAW_LINE,STYLE_SOLID,2,Signal_Color);
   SetIndexStyle(5,DRAW_LINE,STYLE_DOT,1,Signal_Color);
   SetIndexStyle(6,DRAW_LINE,STYLE_DOT,1,Signal_Color);
   SetIndexStyle(7,DRAW_LINE,STYLE_DOT,1,Signal_Color);
   SetIndexStyle(8,DRAW_LINE,STYLE_DOT,1,Signal_Color);
//---
   if(!Movable_Lines) ObjectDelete("Start-Line-N"+window_id);
   if(!Movable_Lines) ObjectDelete("Finish-Line-N"+window_id);
//---
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(error) return(0);
   if(CheckNewBar())
     {
      DefineFormula(); if(error) return(0);
      DefineInterval(); if(error) return(0);
      CalculateEquity(); if(error) return(0);
      CalculateRegression(); if(error) return(0);
      NormalizeVolume(); if(error) return(0);
      DisplayFormula();
      PrepareChart(true);
      DisplayChart();
      DisplayModel();
      CalculateVolatility();
      DisplayIndicators();
      DisplayGrid();
      UpdateStatus();
      ExportEquityData();
     }
   else
     {
      PrepareChart(false);
      DisplayChart();
      DisplayIndicators();
      UpdateStatus();
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int n=ObjectsTotal(); n>=1; n--)
     {
      string name=ObjectName(n-1);
      if(ObjectFind(name)!=window) continue;
      if(StringFind(name,"Formula-label-N"+window_id)!=-1) ObjectDelete(name);
      if(StringFind(name,"Grid-level-N"+window_id)!=-1) ObjectDelete(name);
      if(StringFind(name,"Data-label-N"+window_id)!=-1) ObjectDelete(name);
      if(StringFind(name,"Portfolio-Bid-N"+window_id)!=-1) ObjectDelete(name);
      if(StringFind(name,"Portfolio-Ask-N"+window_id)!=-1) ObjectDelete(name);
     }
   GlobalVariableDel("Equity-"+portfolio_id);
   if(!Movable_Lines) ObjectDelete("Start-Line-N"+window_id);
   if(!Movable_Lines) ObjectDelete("Finish-Line-N"+window_id);
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
//---
   if(error) return;
//---
   if(id==CHARTEVENT_OBJECT_DRAG)
      if(sparam=="Start-Line-N"+window_id || sparam=="Finish-Line-N"+window_id)
        {
         DefineFormula(); if(error) return;
         DefineInterval(); if(error) return;
         CalculateEquity(); if(error) return;
         CalculateRegression(); if(error) return;
         NormalizeVolume(); if(error) return;
         DisplayFormula();
         PrepareChart(true);
         DisplayChart();
         DisplayModel();
         CalculateVolatility();
         DisplayIndicators();
         DisplayGrid();
         UpdateStatus();
         ExportEquityData();
        }
//---
   if(id==CHARTEVENT_OBJECT_CLICK)
      if(StringFind(sparam,"Data-label-N"+window_id)!=-1)
        {
         if(Show_Bid_Ask==none) Show_Bid_Ask=longs;
         else if(Show_Bid_Ask==longs) Show_Bid_Ask=shorts;
         else if(Show_Bid_Ask==shorts) Show_Bid_Ask=none;
         UpdateStatus();
        }
//---
   if(id==CHARTEVENT_OBJECT_CLICK)
      if(StringFind(sparam,"Formula-label-N"+window_id)!=-1)
        {
         if(Chart_Type==single) Chart_Type=dual;
         else if(Chart_Type==dual) Chart_Type=single;
         if(Draw_Histogram && Chart_Type==single)
            SetIndexStyle(0,DRAW_HISTOGRAM,STYLE_SOLID,1,Basis_Color);
         else SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,1,Basis_Color);
         DefineFormula(); if(error) return;
         DefineInterval(); if(error) return;
         CalculateEquity(); if(error) return;
         CalculateRegression(); if(error) return;
         NormalizeVolume(); if(error) return;
         DisplayFormula();
         PrepareChart(true);
         DisplayChart();
         DisplayModel();
         CalculateVolatility();
         DisplayIndicators();
         DisplayGrid();
         UpdateStatus();
         ExportEquityData();
        }
//---
   if(id==CHARTEVENT_OBJECT_DRAG)
      if(sparam=="RSI-zero-N"+window_id || sparam=="MACD-zero-N"+window_id)
        {
         PrepareChart(true);
         DisplayChart();
         CalculateVolatility();
         DisplayIndicators();
         DisplayGrid();
         UpdateStatus();
        }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DefineFormula()
  {
//---
   variables=0;
   string name="";
   int length=StringLen(Basis_Formula);
   for(int index=0; index<length; index++)
     {
      string character=StringSubstr(Basis_Formula,index,1);
      if(character!=" ") name=name+character;
      if(character==" " || index==length-1)
         if(StringLen(name)>0)
           {
            variables++;
            ArrayResize(SYMBOLS,variables);
            ArrayResize(LOTS,variables);
            ArrayResize(ROOTS,variables);
            SYMBOLS[variables-1]=name;
            name="";
           }
     }
//---
   if(Model_Type==spread || Model_Type==fixed)
     {
      constants=0;
      length=StringLen(Offset_Formula);
      for(int index=0; index<length; index++)
        {
         string character=StringSubstr(Offset_Formula,index,1);
         if(character!=" ") name=name+character;
         if(character==" " || index==length-1)
            if(StringLen(name)>0)
              {
               constants++;
               ArrayResize(SYMBOLS,variables+constants);
               ArrayResize(LOTS,variables+constants);
               ArrayResize(ROOTS,variables+constants);
               SYMBOLS[variables+constants-1]=name;
               name="";
              }
        }
     }
//---
   for(int i=0; i<variables+constants; i++)
     {
      length=StringLen(SYMBOLS[i]);
      int index=StringFind(SYMBOLS[i],Formula_Delimiter);
      if(index==-1) LOTS[i]=1;
      else LOTS[i]=StrToDouble(StringSubstr(SYMBOLS[i],index+1,length-index-1));
      SYMBOLS[i]=StringSubstr(SYMBOLS[i],0,index);
     }
//---
   if(variables==0)
     { Alert("Basis formula not defined!"); error=true; return; }
   if(constants==0 && Model_Type==spread)
     { Alert("Offset formula not defined!"); error=true; return; }
   for(int i=0; i<variables+constants; i++)
      if(MarketInfo(SYMBOLS[i],MODE_POINT)==0)
        { Alert("Missing symbol! - ",SYMBOLS[i]); error=true; return; }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DefineInterval()
  {
//---
   for(int n=ObjectsTotal(); n>=1; n--)
     {
      string name=ObjectName(n-1);
      if(ObjectFind(name)!=window) continue;
      if(ObjectType(name)!=OBJ_VLINE) continue;
      if(StringFind(name,"Start-Line-N"+window_id)!=-1) zero_time=(datetime)ObjectGet(name,OBJPROP_TIME1);
      if(StringFind(name,"Finish-Line-N"+window_id)!=-1) limit_time=(datetime)ObjectGet(name,OBJPROP_TIME1);
     }
//---
   if(zero_time==0 || limit_time==0)
     {
      zero_time=Start_Time;
      limit_time=MathMin(iTime(Symbol(),Timeframe,0),Finish_Time);
      PlaceVertical("Start-Line-N"+window_id,zero_time,Red,STYLE_DOT,true,Movable_Lines);
      PlaceVertical("Finish-Line-N"+window_id,limit_time,Red,STYLE_DOT,true,Movable_Lines);
     }
//---
   bool scan_history=true;
   while(scan_history && zero_time<=limit_time)
     {
      scan_history=false;
      for(int i=0; i<variables+constants; i++)
         if(iBarShift(SYMBOLS[i],Timeframe,zero_time,true)==-1)
            scan_history=true;
      if(scan_history) zero_time+=Timeframe*60;
     }
//---
   if(zero_time>=limit_time) { Alert("Missing history data!"); error=true; return; }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateEquity()
  {
//---
   ArrayResize(opening,variables+constants);
   ArrayResize(closing,variables+constants);
   ArrayResize(profit,variables+constants);
//---
   for(int i=0; i<variables+constants; i++)
     {
      int shift=iBarShift(SYMBOLS[i],Timeframe,zero_time);
      opening[i]=iClose(SYMBOLS[i],Timeframe,shift);
     }
//---
   int max_bars=iBars(Symbol(),Timeframe);
   ArrayResize(EQUITY,max_bars);
   ArrayResize(TIMES,max_bars);
//---
   points=0;
   datetime current_time=zero_time;
   while(current_time<=limit_time)
     {
      bool skip_bar=false;
      for(int i=0; i<variables+constants; i++)
         if(iBarShift(SYMBOLS[i],Timeframe,current_time,true)==-1)
            skip_bar=true;
      if(!skip_bar)
        {
         points++;
         TIMES[points-1]=current_time;
         for(int i=0; i<variables+constants; i++)
           {
            int shift=iBarShift(SYMBOLS[i],Timeframe,current_time);
            closing[i]=iClose(SYMBOLS[i],Timeframe,shift);
            double CV=ContractValue(SYMBOLS[i],current_time,Timeframe);
            profit[i]=(closing[i]-opening[i])*CV;
            EQUITY[points-1,i]=profit[i];
           }
        }
      current_time+=Timeframe*60;
     }
//---
   ArrayResize(EQUITY,points);
   ArrayResize(TIMES,points);
   ArrayResize(MODEL,points);
//---
   if(points<3) { Alert("Insufficient history data!"); error=true; return; }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateRegression()
  {
//---
   if(Model_Type==fixed) return;
//---
   if(Model_Type==spread)
     {
      int info,i,j;
      CLinearModelShell LM;
      CLRReportShell AR;
      CLSFitReportShell report;
      CMatrixDouble MATRIX(points,variables+1);
      for(i=0; i<variables; i++) for(j=0; j<points; j++) MATRIX[j].Set(i,EQUITY[j,i]);
      ArrayInitialize(MODEL,0);
      for(i=variables; i<variables+constants; i++) for(j=0; j<points; j++) MODEL[j]+=EQUITY[j,i]*LOTS[i];
      for(j=0; j<points; j++) MATRIX[j].Set(variables,MODEL[j]);
      CAlglib::LRBuildZ(MATRIX,points,variables,info,LM,AR);
      if(info<0) { Alert("Error in regression model!"); error=true; return; }
      CAlglib::LRUnpack(LM,ROOTS,variables);
      ROOTS[variables]=1;
     }
//---
   if(Model_Type==trend)
     {
      int info,i,j;
      CLinearModelShell LM;
      CLRReportShell AR;
      CLSFitReportShell report;
      CMatrixDouble MATRIX(points,variables+1);
      if(Model_Increment==0) { Alert("Zero model increment!"); error=true; return; }
      for(j=0; j<points; j++) MODEL[j]=j*Model_Increment;
      for(i=0; i<variables; i++) for(j=0; j<points; j++) MATRIX[j].Set(i,EQUITY[j,i]);
      for(j=0; j<points; j++) MATRIX[j].Set(variables,MODEL[j]);
      CAlglib::LRBuildZ(MATRIX,points,variables,info,LM,AR);
      if(info<0) { Alert("Error in regression model!"); error=true; return; }
      CAlglib::LRUnpack(LM,ROOTS,variables);
     }
//---
   if(Model_Type==oscillator)
     {
      int info,i,j;
      CLinearModelShell LM;
      CLRReportShell AR;
      CLSFitReportShell report;
      CMatrixDouble MATRIX(points,variables+1);
      if(Model_Cycles==0)    { Alert("Zero model cycles!"); error=true; return; }
      if(Model_Amplitude==0) { Alert("Zero model amplitude!"); error=true; return; }
      double Model_Period=points/Model_Cycles;
      for(j=0; j<points; j++) MODEL[j]=Model_Amplitude*sin(2*M_PI*(j/Model_Period-Model_Phase));
      double zero_shift=-MODEL[0]; if(zero_shift!=0) for(j=0; j<points; j++) MODEL[j]+=zero_shift;
      for(i=0; i<variables; i++) for(j=0; j<points; j++) MATRIX[j].Set(i,EQUITY[j,i]);
      for(j=0; j<points; j++) MATRIX[j].Set(variables,MODEL[j]);
      CAlglib::LRBuildZ(MATRIX,points,variables,info,LM,AR);
      if(info<0) { Alert("Error in regression model!"); error=true; return; }
      CAlglib::LRUnpack(LM,ROOTS,variables);
     }
//---
   if(Model_Type==hybrid)
     {
      int info,i,j;
      CLinearModelShell LM;
      CLRReportShell AR;
      CLSFitReportShell report;
      CMatrixDouble MATRIX(points,variables+1);
      if(Model_Increment==0) { Alert("Zero model increment!"); error=true; return; }
      if(Model_Cycles==0)    { Alert("Zero model cycles!"); error=true; return; }
      if(Model_Amplitude==0) { Alert("Zero model amplitude!"); error=true; return; }
      double Model_Period=points/Model_Cycles;
      for(j=0; j<points; j++) MODEL[j]=Model_Amplitude*sin(2*M_PI*(j/Model_Period-Model_Phase))+Model_Increment*j;
      double zero_shift=-MODEL[0]; if(zero_shift!=0) for(j=0; j<points; j++) MODEL[j]+=zero_shift;
      for(i=0; i<variables; i++) for(j=0; j<points; j++) MATRIX[j].Set(i,EQUITY[j,i]);
      for(j=0; j<points; j++) MATRIX[j].Set(variables,MODEL[j]);
      CAlglib::LRBuildZ(MATRIX,points,variables,info,LM,AR);
      if(info<0) { Alert("Error in regression model!"); error=true; return; }
      CAlglib::LRUnpack(LM,ROOTS,variables);
     }
//---
   if(Model_Type==root)
     {
      int info,i,j;
      CLinearModelShell LM;
      CLRReportShell AR;
      CLSFitReportShell report;
      CMatrixDouble MATRIX(points,variables+1);
      if(Model_Amplitude==0) { Alert("Zero model amplitude!"); error=true; return; }
      double Model_Period=points;
      for(j=0; j<points; j++)
        {
         double x=(j/Model_Period-Model_Phase);
         if(x>0) MODEL[j]=Model_Amplitude*MathSqrt(x);
         else MODEL[j]=-Model_Amplitude*MathSqrt(-x);
        }
      double zero_shift=-MODEL[0]; if(zero_shift!=0) for(j=0; j<points; j++) MODEL[j]+=zero_shift;
      for(i=0; i<variables; i++) for(j=0; j<points; j++) MATRIX[j].Set(i,EQUITY[j,i]);
      for(j=0; j<points; j++) MATRIX[j].Set(variables,MODEL[j]);
      CAlglib::LRBuildZ(MATRIX,points,variables,info,LM,AR);
      if(info<0) { Alert("Error in regression model!"); error=true; return; }
      CAlglib::LRUnpack(LM,ROOTS,variables);
     }
//---
   if(Model_Type==abs_root)
     {
      int info,i,j;
      CLinearModelShell LM;
      CLRReportShell AR;
      CLSFitReportShell report;
      CMatrixDouble MATRIX(points,variables+1);
      if(Model_Amplitude==0) { Alert("Zero model amplitude!"); error=true; return; }
      double Model_Period=points;
      for(j=0; j<points; j++)
        {
         double x=(j/Model_Period-Model_Phase);
         if(x>0) MODEL[j]=Model_Amplitude*MathSqrt(x);
         else MODEL[j]=Model_Amplitude*MathSqrt(-x);
        }
      double zero_shift=-MODEL[0]; if(zero_shift!=0) for(j=0; j<points; j++) MODEL[j]+=zero_shift;
      for(i=0; i<variables; i++) for(j=0; j<points; j++) MATRIX[j].Set(i,EQUITY[j,i]);
      for(j=0; j<points; j++) MATRIX[j].Set(variables,MODEL[j]);
      CAlglib::LRBuildZ(MATRIX,points,variables,info,LM,AR);
      if(info<0) { Alert("Error in regression model!"); error=true; return; }
      CAlglib::LRUnpack(LM,ROOTS,variables);
     }
//---
   if(Model_Type==fitting)
     {
      int info,i,j;
      CLSFitReportShell report;
      CMatrixDouble CONSTRAIN(1,variables+1);
      for(i=0; i<variables; i++) CONSTRAIN[0].Set(i,1);
      CONSTRAIN[0].Set(variables,1);
      CMatrixDouble MATRIX(points,variables);
      for(i=0; i<variables; i++) for(j=0; j<points; j++) MATRIX[j].Set(i,EQUITY[j,i]);
      for(j=0; j<points; j++) MODEL[j]=0;
      CAlglib::LSFitLinearC(MODEL,MATRIX,CONSTRAIN,points,variables,1,info,ROOTS,report);
      if(info<0) { Alert("Error in linear fitting model!"); error=true; return; }
     }
//---
   if(Model_Type==principal)
     {
      int info,i,j;
      double VAR[];
      ArrayResize(VAR,variables);
      CMatrixDouble MATRIX(points,variables);
      CMatrixDouble VECTOR(variables,variables);
      for(i=0; i<variables; i++) for(j=0; j<points; j++) MATRIX[j].Set(i,EQUITY[j,i]);
      CAlglib::PCABuildBasis(MATRIX,points,variables,info,VAR,VECTOR);
      if(info<0) { Alert("Error in principal component model!"); error=true; return; }
      for(i=0; i<variables; i++) ROOTS[i]=VECTOR[i][variables-1];
     }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void NormalizeVolume()
  {
//---
   if(Model_Type!=fixed)
      for(int i=0; i<variables; i++) LOTS[i]=ROOTS[i];
//---
   if(Portfolio_Value!=0)
     {
      double total_value=0;
      for(int i=0; i<variables+constants; i++)
         total_value+=closing[i]*ContractValue(SYMBOLS[i],limit_time,Timeframe)*MathAbs(LOTS[i]);
      if(total_value==0) { Alert("Zero portfolio value!"); error=true; return; }
      scale_volume=Portfolio_Value/total_value;
     }
   else
     {
      if(Portfolio_Value==0)
         if(Model_Type==fitting || Model_Type==principal)
           { Alert("Portfolio value not defined!"); error=true; return; }
      scale_volume=1;
     }
//---
   for(int i=0; i<variables+constants; i++)
      LOTS[i]=NormalizeDouble(LOTS[i]*scale_volume,Lots_Digits);
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateVolatility()
  {
//---
   double max=-1.7976931348623158e+308,min=1.7976931348623158e+308;
   for(int j=start_bar; j>=finish_bar; j--)
     {
      if(basis[j]-offset[j]>max) max=basis[j]-offset[j];
      if(basis[j]-offset[j]<min) min=basis[j]-offset[j];
     }
   deviation=NormalizeDouble(max-min,2);
//---
   max=-1.7976931348623158e+308; min=1.7976931348623158e+308;
   for(int j=start_bar; j>=finish_bar; j--)
     {
      if(basis[j]>max) max=basis[j];
      if(basis[j]<min) min=basis[j];
     }
   range=NormalizeDouble(max-min,2);
   if(Model_Type==fixed || Model_Type==spread) range=deviation;
//---   
   if(deviation==0) { Alert("Zero portfolio volatility!"); error=true; return; }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PrepareChart(bool all_bars)
  {
   if(all_bars)
     {
      ArrayInitialize(basis,EMPTY_VALUE);
      ArrayInitialize(offset,EMPTY_VALUE);
      ArrayInitialize(MA_data,EMPTY_VALUE);
      ArrayInitialize(upper_outer,EMPTY_VALUE);
      ArrayInitialize(upper_inner,EMPTY_VALUE);
      ArrayInitialize(lower_inner,EMPTY_VALUE);
      ArrayInitialize(lower_outer,EMPTY_VALUE);
      ArrayInitialize(RSI_data,EMPTY_VALUE);
      ArrayInitialize(MACD_data,EMPTY_VALUE);
      start_bar=iBarShift(Symbol(),Period(),zero_time,true);
      finish_bar=iBarShift(Symbol(),Period(),limit_time);
      if(start_bar>0) scale_points=(double)points/(start_bar-finish_bar+1);
      else scale_points=(double)Timeframe/Period();
      start_bar=iBarShift(Symbol(),Period(),zero_time);
      finish_bar=iBarShift(Symbol(),Period(),limit_time);
      if(Show_History) open_bar=Bars-1;
      else open_bar=MathMin(Bars-1,start_bar);
      if(Show_Forward) close_bar=0;
      else close_bar=finish_bar;
     }
   else
     {
      open_bar=0;
      close_bar=0;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DisplayChart()
  {
//---
   if(!Show_Forward) if(open_bar==close_bar) return;
//---
   for(int j=open_bar; j>=close_bar; j--)
     {
      //---
      double sum_A=0;
      for(int i=0; i<variables; i++)
        {
         int shift=iBarShift(SYMBOLS[i],Period(),Time[j]);
         closing[i]=iClose(SYMBOLS[i],Period(),shift);
         double CV=ContractValue(SYMBOLS[i],Time[j],Period());
         profit[i]=(closing[i]-opening[i])*CV*LOTS[i];
         sum_A+=invert*profit[i];
        }
      //---
      double sum_B=0;
      for(int i=variables; i<variables+constants; i++)
        {
         int shift=iBarShift(SYMBOLS[i],Period(),Time[j]);
         closing[i]=iClose(SYMBOLS[i],Period(),shift);
         double CV=ContractValue(SYMBOLS[i],Time[j],Period());
         profit[i]=(closing[i]-opening[i])*CV*LOTS[i];
         sum_B+=invert*profit[i];
        }
      //---
      if(Chart_Type==dual && (Model_Type==fixed || Model_Type==spread))
           {
            basis[j]=NormalizeDouble(sum_A,2);
            offset[j]=NormalizeDouble(sum_B,2);
           }
      else
         basis[j]=NormalizeDouble(sum_A-sum_B,2);
      //---
     }
//---
   if(Sync_Last_Bar)
     {
      bool sync=true;
      for(int i=0; i<variables+constants; i++)
         if(iTime(SYMBOLS[i],NULL,0)!=Time[0]) sync=false;
      if(!sync) { basis[0]=EMPTY_VALUE; offset[0]=EMPTY_VALUE; }
     }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DisplayModel()
  {
//---
   if(!Draw_Model) return;
   if(open_bar==close_bar) return;
   if(Chart_Type==dual && Model_Type==spread) return;
   if(Chart_Type==dual && Model_Type==fixed) return;
//---
   for(int j=open_bar; j>=close_bar; j--)
     {
      double model=0;
      if(Model_Type==hybrid)
        {
         double index=scale_points*(start_bar-j);
         double Model_Period=points/Model_Cycles;
         model=Model_Amplitude*sin(2*M_PI*(index/Model_Period-Model_Phase))+Model_Increment*index;
         model*=scale_volume;
        }
      if(Model_Type==oscillator)
        {
         double index=scale_points*(start_bar-j);
         double Model_Period=points/Model_Cycles;
         model=Model_Amplitude*sin(2*M_PI*(index/Model_Period-Model_Phase));
         model*=scale_volume;
        }
      if(Model_Type==trend)
        {
         double index=scale_points*(start_bar-j);
         model=Model_Increment*index;
         model*=scale_volume;
        }
      if(Model_Type==root)
        {
         double index=scale_points*(start_bar-j);
         double Model_Period=points;
         double x=index/Model_Period-Model_Phase;
         if(x>0) model=Model_Amplitude*MathSqrt(x);
         else model=-Model_Amplitude*MathSqrt(-x);
         model*=scale_volume;
        }
      if(Model_Type==abs_root)
        {
         double index=scale_points*(start_bar-j);
         double Model_Period=points;
         double x=index/Model_Period-Model_Phase;
         if(x>0) model=Model_Amplitude*MathSqrt(x);
         else model=Model_Amplitude*MathSqrt(-x);
         model*=scale_volume;
        }
      offset[j]=NormalizeDouble(model,2);
     }
//---
   if(Model_Type!=spread && Model_Type!=fixed)
     {
      double price_shift=offset[start_bar];
      for(int j=open_bar; j>=close_bar; j--) offset[j]-=price_shift;
     }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DisplayIndicators()
  {
//---
   if(Chart_Type==dual) return;
//---
   if(MA_period>0)
     {
      int MA_open_bar=open_bar-(MA_period-1);
      for(int j=MA_open_bar; j>=close_bar; j--)
        {
         if(Channels_Type==empty)
           {
            double MA=0;
            for(int k=0; k<MA_period; k++) MA+=basis[j+k];
            MA/=MA_period;
            MA_data[j]=NormalizeDouble(MA,2);
           }
         if(Channels_Type==envelopes)
           {
            double MA=0;
            for(int k=0; k<MA_period; k++) MA+=basis[j+k];
            MA/=MA_period;
            MA_data[j]=NormalizeDouble(MA,2);
            upper_outer[j]=NormalizeDouble(MA_data[j]+Outer_Channel,2);
            upper_inner[j]=NormalizeDouble(MA_data[j]+Inner_Channel,2);
            lower_inner[j]=NormalizeDouble(MA_data[j]-Inner_Channel,2);
            lower_outer[j]=NormalizeDouble(MA_data[j]-Outer_Channel,2);
           }
         if(Channels_Type==bollinger)
           {
            double MA=0;
            for(int k=0; k<MA_period; k++) MA+=basis[j+k];
            MA/=MA_period;
            double SD=0;
            for(int k=0; k<MA_period; k++) SD+=MathPow(basis[j+k]-MA,2);
            SD=MathSqrt(SD/MA_period);
            MA_data[j]=NormalizeDouble(MA,2);
            upper_outer[j]=NormalizeDouble(MA_data[j]+SD*Outer_Channel,2);
            upper_inner[j]=NormalizeDouble(MA_data[j]+SD*Inner_Channel,2);
            lower_inner[j]=NormalizeDouble(MA_data[j]-SD*Inner_Channel,2);
            lower_outer[j]=NormalizeDouble(MA_data[j]-SD*Outer_Channel,2);
           }
         if(Channels_Type==transcendent)
           {
            double MA=0;
            for(int k=0; k<MA_period; k++) MA+=basis[j+k];
            MA/=MA_period;
            double sum=0;
            for(int k=0; k<MA_period-1; k++) sum+=MathAbs(basis[j+k]-basis[j+k+1]);
            double delta=sum/MathSqrt(MA_period);
            MA_data[j]=NormalizeDouble(MA,2);
            upper_outer[j]=NormalizeDouble(MA_data[j]+delta*Outer_Channel,2);
            upper_inner[j]=NormalizeDouble(MA_data[j]+delta*Inner_Channel,2);
            lower_inner[j]=NormalizeDouble(MA_data[j]-delta*Inner_Channel,2);
            lower_outer[j]=NormalizeDouble(MA_data[j]-delta*Outer_Channel,2);
           }
        }
     }
//---
   if(MACD_fast>0 && MACD_slow>0)
     {
      double MACD_zero_level=0;
      for(int n=ObjectsTotal(); n>=1; n--)
        {
         string name=ObjectName(n-1);
         if(ObjectFind(name)!=window) continue;
         if(ObjectType(name)!=OBJ_HLINE) continue;
         if(StringFind(name,"MACD-zero-N"+window_id)!=-1)
            MACD_zero_level=ObjectGet(name,OBJPROP_PRICE1);
        }
      if(MACD_zero_level==0)
        {
         MACD_zero_level=NormalizeDouble(1.5*deviation*MathSqrt(MACD_fast),2);
         PlaceHorizontal("MACD-zero-N"+window_id,MACD_zero_level,Silver,STYLE_DOT,true,true);
        }
      int MACD_open_bar=open_bar-(MathMax(MACD_fast,MACD_slow)-1);
      for(int j=MACD_open_bar; j>=close_bar; j--)
        {
         double MA_fast=0;
         for(int k=0; k<MACD_fast; k++) MA_fast+=basis[j+k];
         MA_fast/=MACD_fast;
         double MA_slow=0;
         for(int k=0; k<MACD_slow; k++) MA_slow+=basis[j+k];
         MA_slow/=MACD_slow;
         MACD_data[j]=(MA_fast-MA_slow)+MACD_zero_level;
         MACD_data[j]=NormalizeDouble(MACD_data[j],2);
        }
     }
   else ObjectDelete("MACD-zero-N"+window_id);
//---
   if(RSI_period>2)
     {
      double RSI_zero_level=0;
      for(int n=ObjectsTotal(); n>=1; n--)
        {
         string name=ObjectName(n-1);
         if(ObjectFind(name)!=window) continue;
         if(ObjectType(name)!=OBJ_HLINE) continue;
         if(StringFind(name,"RSI-zero-N"+window_id)!=-1)
            RSI_zero_level=ObjectGet(name,OBJPROP_PRICE1);
        }
      if(RSI_zero_level==0)
        {
         RSI_zero_level=NormalizeDouble(-1.5*deviation*MathSqrt(RSI_period),2);
         PlaceHorizontal("RSI-zero-N"+window_id,RSI_zero_level,Silver,STYLE_DOT,true,true);
        }
      int RSI_open_bar=open_bar-(RSI_period-1);
      if(RSI_open_bar-close_bar+1<RSI_period) RSI_open_bar=close_bar+(RSI_period-1);
      int i,counted_bars=0;
      double rel,negative,positive;
      double PosBuffer[],NegBuffer[];
      int size=ArraySize(RSI_data);
      ArrayResize(PosBuffer,size);
      ArrayResize(NegBuffer,size);
      i=RSI_open_bar-RSI_period;
      if(counted_bars>=RSI_period) i=RSI_open_bar-counted_bars;
      while(i>=0)
        {
         double sumn=0.0,sump=0.0;
         if(i==RSI_open_bar-RSI_period)
           {
            int k=RSI_open_bar-1;
            while(k>=i)
              {
               rel=basis[k]-basis[k+1];
               if(rel>0) sump+=rel;
               else      sumn-=rel;
               k--;
              }
            positive=sump/RSI_period;
            negative=sumn/RSI_period;
           }
         else
           {
            rel=basis[i]-basis[i+1];
            if(rel>0) sump=rel;
            else      sumn=-rel;
            positive=(PosBuffer[i+1]*(RSI_period-1)+sump)/RSI_period;
            negative=(NegBuffer[i+1]*(RSI_period-1)+sumn)/RSI_period;
           }
         PosBuffer[i]=positive;
         NegBuffer[i]=negative;
         if(negative==0.0) RSI_data[i]=0.0;
         else RSI_data[i]=1-1/(1+positive/negative);
         RSI_data[i]=(RSI_data[i]-0.5)*deviation*MathSqrt(RSI_period)+RSI_zero_level;
         RSI_data[i]=NormalizeDouble(RSI_data[i],2);
         i--;
        }
     }
   else ObjectDelete("RSI-zero-N"+window_id);
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateStatus()
  {
//---
   spread_sum=0;
   margin_sum=0;
   commission_sum=0;
   for(int i=0; i<variables+constants; i++)
     {
      double CV=ContractValue(SYMBOLS[i],Time[0],Period());
      double pips = MarketInfo(SYMBOLS[i],MODE_ASK) - MarketInfo(SYMBOLS[i],MODE_BID);
      spread_sum += pips * CV * MathAbs(LOTS[i]);
      margin_sum += MarketInfo(SYMBOLS[i],MODE_MARGINREQUIRED) * MathAbs(LOTS[i]);
      commission_sum+=Commission_Rate/100*CV*MathAbs(LOTS[i])*iClose(SYMBOLS[i],0,0);
     }
   spread_sum=NormalizeDouble(spread_sum,2);
   margin_sum=NormalizeDouble(margin_sum,2);
   commission_sum=NormalizeDouble(commission_sum,2);
//---
   int line_shift=25+(variables+constants+1)*12;
   string text = "Range: " + DoubleToString(range,2) + " " + Chart_Currency;
   string name = "Data-label-N" + window_id + "-A";
   PlaceLabel(name,5,line_shift,Text_Corner,text,Basis_Color,"Tahoma",8);
//---
   line_shift+=12;
   text = "Deviation: " + DoubleToString(deviation,2) + " " + Chart_Currency;
   name = "Data-label-N" + window_id + "-B";
   PlaceLabel(name,5,line_shift,Text_Corner,text,Basis_Color,"Tahoma",8);
//---
   line_shift+=12;
   text = "Margin: " + DoubleToString(margin_sum,2) + " " + AccountCurrency();
   name = "Data-label-N" + window_id + "-C";
   PlaceLabel(name,5,line_shift,Text_Corner,text,Basis_Color,"Tahoma",8);
//---
   line_shift+=12;
   name = "Data-label-N" + window_id + "-D";
   text = "Commission: " + DoubleToString(commission_sum,2) + " " + Chart_Currency;
   PlaceLabel(name,5,line_shift,Text_Corner,text,Basis_Color,"Tahoma",8);
//---
   line_shift+=12;
   name = "Data-label-N" + window_id + "-E";
   text = "Spread: " + DoubleToString(spread_sum,2) + " " + Chart_Currency;
   PlaceLabel(name,5,line_shift,Text_Corner,text,Basis_Color,"Tahoma",8);
//---
   if(Show_Bid_Ask==longs)
     {
      ObjectDelete("Portfolio-Bid-N"+window_id);
      ObjectDelete("Portfolio-Ask-N"+window_id);
      PlaceHorizontal("Portfolio-Ask-N"+window_id,basis[0]+spread_sum+commission_sum,Red,STYLE_SOLID,false,false);
      PlaceHorizontal("Portfolio-Bid-N"+window_id,basis[0],Red,STYLE_SOLID,false,false);
     }
   if(Show_Bid_Ask==shorts)
     {
      ObjectDelete("Portfolio-Bid-N"+window_id);
      ObjectDelete("Portfolio-Ask-N"+window_id);
      PlaceHorizontal("Portfolio-Ask-N"+window_id,basis[0],Red,STYLE_SOLID,false,false);
      PlaceHorizontal("Portfolio-Bid-N"+window_id,basis[0]-spread_sum-commission_sum,Red,STYLE_SOLID,false,false);
     }
   if(Show_Bid_Ask==none)
     {
      ObjectDelete("Portfolio-Bid-N"+window_id);
      ObjectDelete("Portfolio-Ask-N"+window_id);
     }
//---
   if(basis[0]==EMPTY_VALUE) return;
   if(Model_Type!=fixed && Model_Type!=spread) GlobalVariableSet("Portfolio-"+portfolio_id,basis[0]);
   else if(offset[0]==EMPTY_VALUE) GlobalVariableSet("Portfolio-"+portfolio_id,basis[0]);
   else GlobalVariableSet("Portfolio-"+portfolio_id,basis[0]-offset[0]);
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ContractValue(string symbol,datetime time,int period)
  {
//---
   double value=MarketInfo(symbol,MODE_LOTSIZE);
   string quote=SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT);
//---
   if(quote!="USD")
     {
      string direct=FX_prefix+quote+"USD"+FX_postfix;
      if(MarketInfo(direct,MODE_POINT)!=0)
        {
         int shift=iBarShift(direct,period,time);
         double price=iClose(direct,period,shift);
         if(price>0) value*=price;
        }
      else
        {
         string indirect=FX_prefix+"USD"+quote+FX_postfix;
         int shift=iBarShift(indirect,period,time);
         double price=iClose(indirect,period,shift);
         if(price>0) value/=price;
        }
     }
//---
   if(Chart_Currency!="USD")
     {
      string direct=FX_prefix+Chart_Currency+"USD"+FX_postfix;
      if(MarketInfo(direct,MODE_POINT)!=0)
        {
         int shift=iBarShift(direct,period,time);
         double price=iClose(direct,period,shift);
         if(price>0) value/=price;
        }
      else
        {
         string indirect=FX_prefix+"USD"+Chart_Currency+FX_postfix;
         int shift=iBarShift(indirect,period,time);
         double price=iClose(indirect,period,shift);
         if(price>0) value*=price;
        }
     }
//---
   return(value);
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DisplayFormula()
  {
   for(int i=0; i<variables+constants; i++)
     {
      string text=SYMBOLS[i]+Formula_Delimiter;
      if(i<variables) if(invert*LOTS[i]>=0) text=text+"+"; else text=text+"-";
      else if(invert*LOTS[i]>=0) text=text+"-"; else text=text+"+";
      text=text+DoubleToString(MathAbs(LOTS[i]),Lots_Digits);
      string name="Formula-label-N"+window_id+"-"+(string)i;
      color colour=Basis_Color; if(Chart_Type==dual && i>=variables) colour=Offset_Color;
      PlaceLabel(name,5,25+i*12,Text_Corner,text,colour,"Tahoma",8);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DisplayGrid()
  {
//---
   if(Chart_Grid_Size==0) return;
//---
   double max=-1.7976931348623158e+308,min=1.7976931348623158e+308;
   for(int j=Bars-1; j>=0; j--)
     {
      double A=basis[j];
      double B=offset[j];
      if(A==EMPTY_VALUE && B==EMPTY_VALUE) continue;
      if(A==EMPTY_VALUE) A=B;
      if(B==EMPTY_VALUE) B=A;
      if(MathMax(A,B)>max) max=MathMax(A,B);
      if(MathMin(A,B)<min) min=MathMin(A,B);
     }
//---
   double level=0;
   while(level<max)
     {
      level+=Chart_Grid_Size;
      string name="Grid-level-N"+window_id+":"+DoubleToString(level,2);
      PlaceHorizontal(name,level,Silver,STYLE_DOT,true,false);
     }
//---
   level=0;
   while(level>min)
     {
      level-=Chart_Grid_Size;
      string name="Grid-level-N"+window_id+":"+DoubleToString(level,2);
      PlaceHorizontal(name,level,Silver,STYLE_DOT,true,false);
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
void PlaceVertical(string name,datetime time,int colour,int style,bool back,bool select)
  {
   ObjectCreate(0,name,OBJ_VLINE,window,time,0);
   ObjectSetInteger(0,name,OBJPROP_COLOR,colour);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_BACK,back);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,select);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PlaceHorizontal(string name,double price,int colour,int style,bool back,bool select)
  {
   ObjectCreate(0,name,OBJ_HLINE,window,0,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,colour);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_BACK,back);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,select);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ExportEquityData()
  {
//---
   if(CSV_Export_File=="") return;
   string working_name=CSV_Export_File+"_model.csv";
   PrepareModelFile(working_name);
   if(error) return;
   for(int j=0; j<points; j++)
     {
      string text=TimeToString(TIMES[j],TIME_DATE|TIME_MINUTES);
      for(int i=0; i<variables+constants; i++)
         text=StringConcatenate(text,CSV_Separator,EQUITY[j,i]);
      text=StringConcatenate(text,CSV_Separator,MODEL[j]);
      double basis_value=0; double offset_value=0;
      for(int i=0; i<variables+constants; i++)
         if(i<variables) basis_value+=NormalizeDouble(EQUITY[j,i]*LOTS[i],2);
      else offset_value+=NormalizeDouble(EQUITY[j,i]*LOTS[i],2);
      text=StringConcatenate(text,CSV_Separator,DoubleToString(basis_value-offset_value,2));
      text=StringConcatenate(text,CSV_Separator,DoubleToString(basis_value,2));
      text=StringConcatenate(text,CSV_Separator,DoubleToString(offset_value,2));
      WriteLine(working_name,text);
     }
//---
   working_name=CSV_Export_File+"_chart.csv";
   PrepareChartFile(working_name);
   if(error) return;
   for(int j=Bars-1; j>=0; j--)
     {
      string text=TimeToString(Time[j],TIME_DATE|TIME_MINUTES);
      text=StringConcatenate(text,CSV_Separator,basis[j]);
      text=StringConcatenate(text,CSV_Separator,offset[j]);
      WriteLine(working_name,text);
     }
//---
   Alert("Equity data export finished.");
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PrepareModelFile(string file)
  {
   int handle=FileOpen(file,FILE_WRITE,Formula_Delimiter);
   if(handle==-1) { Alert("Error opening file!"); error=true; return; }
   FileClose(handle);
   string text="DATE/TIME";
   for(int i=0; i<variables+constants; i++) text=StringConcatenate(text,CSV_Separator,SYMBOLS[i]);
   text=StringConcatenate(text,CSV_Separator,"MODEL");
   text=StringConcatenate(text,CSV_Separator,"PORTFOLIO");
   text=StringConcatenate(text,CSV_Separator,"BASIS");
   text=StringConcatenate(text,CSV_Separator,"OFFSET");
   WriteLine(file,text);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PrepareChartFile(string file)
  {
   int handle=FileOpen(file,FILE_WRITE,Formula_Delimiter);
   if(handle==-1) { Alert("Error opening file!"); error=true; return; }
   FileClose(handle);
   string text="DATE/TIME";
   text=StringConcatenate(text,CSV_Separator,"BASIS");
   text=StringConcatenate(text,CSV_Separator,"OFFSET");
   WriteLine(file,text);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void WriteLine(string file,string text)
  {
   if(error) return;
   int handle=FileOpen(file,FILE_READ|FILE_WRITE,Formula_Delimiter);
   if(handle==-1) return;
   FileSeek(handle,0,SEEK_END);
   FileWrite(handle,text);
   FileClose(handle);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckNewBar()
  {
   static datetime saved_time;
   if(Time[0]==saved_time) return(false);
   saved_time=Time[0];
   return(true);
  }
//+------------------------------------------------------------------+
