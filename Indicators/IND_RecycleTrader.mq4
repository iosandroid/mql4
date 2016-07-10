//+------------------------------------------------------------------+
//|                                            IND_RecycleTrader.mq4 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//#property copyright "Copyright 2015, MetaQuotes Software Corp."
//#property link      "https://www.mql5.com"
//#property version   "1.00"
//#property strict
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
//--- plot Recycle
#property indicator_label1  "Recycle"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot Profit
#property indicator_label2  "Profit"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLime
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- indicator buffers
double ProfitBuffer[];
double RecycleBuffer[];


//-------------------------------------------------------------------------
extern string SymbolBuffer = "GBPUSD; EURNOK; USDJPY; XBRUSD";
extern int    WindowLength = 1440;

//=========================================================================
//
//
class Recycle
{
public:
   Recycle(string symbols, int frame)
      : m_CurrTime(0)
      , m_Frame(frame)
      , m_SymbolCount(0)
   {
      m_SymbolCount = ParseStringOfSymbols(symbols, ";", m_Symbols);
      
      ArrayResize(m_Calc.m_PriceMatrix, m_SymbolCount);
      ArrayResize(m_Calc.m_AvgedMatrix, m_SymbolCount);
      ArrayResize(m_Calc.m_CovarMatrix, m_SymbolCount);      
   }
   
   ~Recycle()
   {
      ArrayFree(m_Calc.m_PriceMatrix);
      ArrayFree(m_Calc.m_AvgedMatrix);
      ArrayFree(m_Calc.m_CovarMatrix);
   }

public:
   int init(int barcount)
   {
      for (int i = 0; i < barcount; i++)
      {   
         calc_recycle_with_offset(i);
      }
      
      return 1;
   }

   void tick()
   {
      static int PrevTime = 0;
      static int InitFlag = 0;
      
      if (InitFlag == 0)
      {
         InitFlag = init(1166);
      }
      
      if (PrevTime != Time[0])
      {        
         return;
      }
      
      PrevTime = Time[0];
      calc_recycle_with_offset(0);      
   }
   
   void draw()
   {
      for (int i = 0; i < m_Data.m_Index; i++)
      {
         int p = iBarShift(Symbol(), Period(), m_Data.m_Time[i]);
         RecycleBuffer[p] = m_Data.m_Recycle[i];
      }      
      WindowRedraw();
   }
   
private:
   void calc_recycle_with_offset( int offset )
   {
      calc_price_matrix(offset);
      calc_covar_matrix();
         
      InvertMatrix(m_Calc.m_CovarMatrix, m_SymbolCount);
         
      calc_recycle_weights(m_Calc.m_Weights);
      calc_recycle();
   }

   double get_price(string symbol, int time)
   {
      return iClose(symbol, Period(), iBarShift(symbol, Period(), time));
   }
   
   datetime get_start_time( int position )
   {
      datetime tmp, start_time;
      int i, addon;

      addon      = iBarShift(m_Symbols[0], Period(), Time[0]);
      start_time = iTime(m_Symbols[0], Period(), position + addon);

      for (i = 1; i < m_SymbolCount; i++)
      {
         addon = iBarShift(m_Symbols[i], Period(), Time[0]);
         tmp   = iTime(m_Symbols[i], Period(), position + addon);

         if (tmp > start_time)
         {
            start_time = tmp;
         }
      }

      return(start_time);
   }

   int get_next_time( int curr_time )
   {
      static int position[MaxSymbols];
      int i, min_time, tmp = -1;

      for (i = 0; i < m_SymbolCount; i++)
      {
         position[i] = iBarShift(m_Symbols[i], Period(), curr_time) - 1;
         if (position[i] >= 0)
         {
            tmp = i;
         }
      }

      if (tmp < 0)
      {
         return(Time[0]);
      }

      min_time = iTime(m_Symbols[tmp], Period(), position[tmp]);

      i = tmp - 1;

      while (i >= 0)
      {
         if (position[i] >= 0)
         {
            tmp = iTime(m_Symbols[i], Period(), position[i]);

            if (tmp < min_time)
            {
               min_time = tmp;
            }
         }

         i--;
      }

      return(min_time);
   }

   void calc_price_matrix(int offset)
   {
      int i, next_time;
      int index = 0;
      
      m_CurrTime = get_start_time(m_Frame + 1 + offset);
      next_time  = get_next_time(m_CurrTime);

      while (next_time < Time[offset])
      {
         m_CurrTime = next_time;

         for (i = 0; i < m_SymbolCount; i++)
         {
            m_Calc.m_PriceMatrix[i][index] = 1000 * MathLog(get_price(m_Symbols[i], m_CurrTime));
         }
         next_time = get_next_time(m_CurrTime);
         
         index++;
      }
      
      m_Calc.m_Dims = index;
   }
   
   //void calc_price_matrix(int offset)
   //{
   //   int i, j;
      
   //   m_CurrTime = Time[offset];
   //   m_Calc.m_Dims = m_Frame;
   
   //   double temp[][MaxPoints];
   //   ArrayResize(temp, m_SymbolCount);
   
   //   for (i = 0; i < m_SymbolCount; i++)
   //   {
   //      for (j = 0; j < m_Calc.m_Dims; j++)
   //      {
   //         temp[i][j] = 1000 * MathLog(get_price(m_Symbols[i], Time[j + offset + 1]));
   //      }
   //   }

   //   // reverse
   //   for (i = 0; i < m_SymbolCount; i++)
   //   {
   //      for (j = 0; j < m_Calc.m_Dims; j++)
   //      {
   //         m_Calc.m_PriceMatrix[i][j] = temp[i][m_Calc.m_Dims-j-1];
   //      }
   //   }      
   //}
   
   void calc_avged_matrix()
   {
      int i, j;
      double sum;

      double means[];
      ArrayResize(means, m_Calc.m_Dims);

      for (i = 0; i < m_SymbolCount; i++)
      {
         sum = 0;

         for (j = m_Calc.m_Dims-1; j >= 0; j--)
         {
            sum += m_Calc.m_PriceMatrix[i][j];
         }

         means[i] = sum / m_Calc.m_Dims;
      }

      for (i = 0; i < m_SymbolCount; i++)
      {
         for (j = m_Calc.m_Dims-1; j >= 0; j--)
         {
            m_Calc.m_AvgedMatrix[i][j] = m_Calc.m_PriceMatrix[i][j] - means[i];  
         }
      }
      
      ArrayFree(means);
   }
   
   void calc_covar_matrix()
   {
      int i, j, k;
      double covar;
      
      calc_avged_matrix();

      for (i = 0; i < m_SymbolCount; i++)
      {
         covar = 0;

         for (k = m_Calc.m_Dims-1; k >= 0; k--)
         {
            covar += m_Calc.m_AvgedMatrix[i][k] * m_Calc.m_AvgedMatrix[i][k];
         }
            
         covar /= m_Calc.m_Dims;
         
         m_Calc.m_CovarMatrix[i][i] = covar;

         for (j = i + 1; j < m_SymbolCount; j++)
         {
            covar = 0;

            for (k = m_Calc.m_Dims-1; k >= 0; k--)
            {
               covar += m_Calc.m_AvgedMatrix[i][k] * m_Calc.m_AvgedMatrix[j][k];
            }

            m_Calc.m_CovarMatrix[i][j] = covar / m_Calc.m_Dims;
         }              
      }
   }
   
   double calc_recycle_weights( double& w[] )
   {
      int i, j;
      
      int pos = 1, step = 2;
      double tmp, max = 0, stddev;
      
      bool flag;
      double vtmp[];
      double variants[];
      
      static bool Flag[], BestFlag[];
      static double BestVector[];

      ArrayResize(vtmp,       m_SymbolCount);
      ArrayResize(Flag,       m_SymbolCount);
      ArrayResize(BestFlag,   m_SymbolCount);
      ArrayResize(BestVector, m_SymbolCount);

      int vcount = MathPow(2, m_SymbolCount - 1) - 1;
      ArrayResize(variants, vcount + 1);

      for (i = 0; i < m_SymbolCount - 1; i++)
      {
         for (j = pos - 1; j < vcount; j += step)
         {
            variants[j] = i;
         }

         pos  <<= 1;
         step <<= 1;
      }
      variants[vcount] = m_SymbolCount - 2;
      vcount++;

      for (i = 0; i < m_SymbolCount; i++)
      {
         tmp = 0;
         j = 0;

         Flag[i] = FALSE;

         while (j < i)
         {
            tmp -= m_Calc.m_CovarMatrix[j][i];
            j++;
         }

         while (j < m_SymbolCount)
         {
            tmp -= m_Calc.m_CovarMatrix[i][j];
            j++;
         }

         vtmp[i] = tmp / 2;
      }

      for (int k = 0; k < vcount; k++)
      {
         i = variants[k];
         
         flag   = TRUE;
         stddev = 0;

         Flag[i] = !Flag[i];         
         vtmp[i] = -vtmp[i];

         j = 0;

         while (j < i)
         {
            if (Flag[j] == Flag[i])
            {
               vtmp[j] -= m_Calc.m_CovarMatrix[j][i];
            }
            else
            {
               vtmp[j] += m_Calc.m_CovarMatrix[j][i];
            }

            if (flag)
            {
               if (vtmp[j] >= 0)
               {
                  stddev += vtmp[j];
               }
               else
               {
                  flag = FALSE;
               }
            }

            j++;
         }

         while (j < m_SymbolCount)
         {
            if (Flag[j] == Flag[i])
            {
               vtmp[j] -= m_Calc.m_CovarMatrix[i][j];
            }
            else
            {
               vtmp[j] += m_Calc.m_CovarMatrix[i][j];
            }

            if (flag)
            {
               if (vtmp[j] >= 0)
               {
                  stddev += vtmp[j];
               }
               else
               {
                  flag = FALSE;
               }
            }

            j++;
         }

         if (flag)
         {
            if (stddev > max)
            {
               max = stddev;

               ArrayCopy(BestVector, vtmp);
               ArrayCopy(BestFlag,   Flag);
            }
         }
      }

      for (i = 0; i < m_SymbolCount; i++)
      {
         if (BestFlag[i])
         {
            BestVector[i] /= -max;
         }
         else
         {
            BestVector[i] /=  max;
         }
      }

      CheckVectorChange(w, BestVector, m_SymbolCount);

      ArrayCopy(w, BestVector);

      stddev = 1 / MathSqrt(max + max);

      return(stddev);
   }
   
   void calc_recycle()
   {
      double recycle = 0;
      for (int i = 0; i < m_SymbolCount; i++)
      {
         recycle += m_Calc.m_AvgedMatrix[i][m_Calc.m_Dims-1] * m_Calc.m_Weights[i];
      }
      
      m_Data.m_Time[m_Data.m_Index]    = m_CurrTime;
      m_Data.m_Recycle[m_Data.m_Index] = recycle;
      
      m_Data.m_Index++;      
   }
   
private:
   enum
   {      
      MaxPoints  = 160000,
      MaxSymbols = 16
   };
      
   int    m_Frame;    // correlation frame length   
   int    m_CurrTime; 
   int    m_SymbolCount;
   string m_Symbols[MaxSymbols]; // array of symbols
   
   // 
   struct Calc
   {
      Calc() : m_Dims(0) {}
      
      int    m_Dims;
   
      double m_Weights[MaxSymbols];
      double m_PriceMatrix[][MaxPoints];
      double m_AvgedMatrix[][MaxPoints];            
      double m_CovarMatrix[][MaxSymbols];
      
   } m_Calc;   
   
   //
   struct Data
   {
      Data() : m_Index(0) {}
   
      int    m_Index;
      int    m_Time[MaxPoints];      
   
      double m_Profit[MaxPoints];
      double m_Recycle[MaxPoints];
      
      double m_Weights[][MaxPoints];
      
   } m_Data;

   
   
private:
   static string RemoveSpacesFromString( string buffer )
   {
      int pos = 0;
      int len = 0;
   
      buffer = StringTrimLeft(buffer);
      buffer = StringTrimRight(buffer);
   
      len = StringLen(buffer) - 1;
      pos = 1;
   
      while (pos < len)
      {
         if (StringGetChar(buffer, pos) == ' ')
         {
            buffer = StringSubstr(buffer, 0, pos) + StringSubstr(buffer, pos + 1, 0);
            len--;
         }
         else
         {
            pos++;
         }
      }
   
     return buffer;
   }
   
   static int ParseStringOfSymbols( string buffer, string separator, string& out[] )
   {
      int pos, len;
      int count = 0;
   
      buffer    = RemoveSpacesFromString(buffer);
      separator = RemoveSpacesFromString(separator);
   
      len = StringLen(separator);
   
      while (count < MaxSymbols)
      {
         pos        = StringFind(buffer, separator);
         out[count] = StringSubstr(buffer, 0, pos);
         
         count++;
   
         if (pos == -1)
         {
            break;
         }
   
         pos   += len;
         buffer = StringSubstr(buffer, pos);
      }
   
      return(count);
   }
   
   static void InvertMatrix( double& m[][], int count )
   {
      static int rn[];
      static double str[], strm[];
      
      int j,k;
      int jved;
      double aved, tmp;

      ArrayResize(rn,   count);
      ArrayResize(str,  count);
      ArrayResize(strm, count);

      for (j = 0; j < count; j++)
      {
         rn[j] = j;
      }

      for (int i = 0; i < count; i++)
      {
         aved = -1;

         for (j = 0; j < count; j++)
         {
            if (rn[j] != -1)
            {
               tmp = MathAbs(m[j][j]);

               if (tmp > aved)
               {
                  aved = tmp;
                  jved = j;
               }
            }
         }

         rn[jved] = -1;

         for (j = 0; j < jved; j++)
         {
            str[j]  = m[j][jved];
            strm[j] = str[j] / aved;
         }

         for (j = jved + 1; j < count; j++)
         {
            str[j]  = m[jved][j];
            strm[j] = str[j] / aved;
         }

         for (j = 0; j < count; j++)
         {
            for (k = j; k < count; k++)
            {
               m[j][k] -= strm[j] * str[k];
            }
         }

         for (j = 0; j < jved; j++)
         {
            m[j][jved] = strm[j];
         }

         for (j = jved + 1; j < count; j++)
         {
            m[jved][j] = strm[j];
         }

         m[jved][jved] = -1 / aved;
      }
      
      ArrayFree(rn);
      ArrayFree(str);
      ArrayFree(strm);
   }
   
   static bool CheckVectorChange( double& v[], double& vchange[], int count )
   {
      int    i;
      bool   res;
      double sum0 = 0, sum1 = 0;
      
      for (i = 0; i < count; i++)
      {
         sum0 += MathAbs(v[i] - vchange[i]);
         sum1 += MathAbs(v[i] + vchange[i]);
      }

      res = (sum0 > sum1);
      if (res)
      {
         for (i = 0; i < count; i++)
         {
            vchange[i] = -vchange[i];
         }
      }

      return(res);
   }
};
Recycle RecycleObject(SymbolBuffer, WindowLength);

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
{
   SetIndexBuffer(0,RecycleBuffer);
   SetIndexBuffer(1,ProfitBuffer);
 
   return(INIT_SUCCEEDED);
}



void start()
{
   RecycleObject.tick();
   RecycleObject.draw();
   
   //Print(Time[0], " ", iBarShift("EURUSD", Period(), Time[0]) );
   //Print(Time[0], " ", iBarShift("GBPUSD", Period(), Time[0]) );
   
   //Print(Time[0], " ", iBarShift(Symbol(), Period(), Time[0]) );
   //Print(Time[1], " ", iBarShift(Symbol(), Period(), Time[1]) );
   //Print(Time[2], " ", iBarShift(Symbol(), Period(), Time[2]) );
   //Print(Time[3], " ", iBarShift(Symbol(), Period(), Time[3]) );
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
//int OnCalculate(const int rates_total,
//                const int prev_calculated,
//                const datetime &time[],
//                const double &open[],
//                const double &high[],
//                const double &low[],
//                const double &close[],
//                const long &tick_volume[],
//                const long &volume[],
//                const int &spread[])
//{
//   Print("OnCalculated");

//---
   
//--- return value of prev_calculated for next call
//   return(rates_total);
//}
//+------------------------------------------------------------------+
