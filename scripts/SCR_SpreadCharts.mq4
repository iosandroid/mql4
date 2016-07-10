//+------------------------------------------------------------------+
//|                                                 SpreadCharts.mq4 |
//|                             Copyright © 2009, Skype: en.ua.en.ua |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Skype: en.ua.en.ua"
#property link      ""

#property indicator_separate_window
#property indicator_level1 0
#property indicator_level2 0

extern int Timeframe = 1;
extern string Symbol_1 = "EURUSD";
extern string Symbol_2 = "GBPUSD";

double Spread[];

int init()
{
   SetIndexBuffer(0,Spread);
   SetIndexStyle(0,DRAW_HISTOGRAM,EMPTY,3,Red);
   return(0);
}

int start()
{
   int k;
   double N = 0;
   double Sum = 0;
   for(k = 0; k < iBars(Symbol_1,Timeframe); k++)
   {
      int symb2Shift = iBarShift(Symbol_2,Timeframe,iTime(Symbol_1,Timeframe,k),true);
      if(symb2Shift != -1)
      {
         Spread[k] = iClose(Symbol_1,Timeframe,k) - iClose(Symbol_2,Timeframe,symb2Shift);
         Sum += Spread[k];
         N++;
      }
      else
      {
         Spread[k] = 0;
      }

   }
   double avarageSpread = Sum / N;
   string message = "Avarage spread: " +  avarageSpread;
   Comment(message);
   return(0);
}