//+------------------------------------------------------------------+
//|                                                       sample.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("Symbol=",Symbol());
   Print("MODE_LOW               " + DoubleToStr(MarketInfo(Symbol(),MODE_LOW))               + " ����������� ������� ����=");
   Print("MODE_HIGH              " + DoubleToStr(MarketInfo(Symbol(),MODE_HIGH))              + " ������������ ������� ����=");
   Print("MODE_TIME              " + DoubleToStr(MarketInfo(Symbol(),MODE_TIME))              + " ����� ����������� ��������� ���������=");
   Print("MODE_BID               " + DoubleToStr(MarketInfo(Symbol(),MODE_BID))               + " ��������� ����������� ���� �����������=");
   Print("MODE_ASK               " + DoubleToStr(MarketInfo(Symbol(),MODE_ASK))               + " ��������� ����������� ���� �������=");
   Print("MODE_POINT             " + DoubleToStr(MarketInfo(Symbol(),MODE_POINT))             + " ������ ������ � ������ ���������=");
   Print("MODE_DIGITS            " + DoubleToStr(MarketInfo(Symbol(),MODE_DIGITS))            + " ���������� ���� ����� ������� � ���� �����������=");
   Print("MODE_SPREAD            " + DoubleToStr(MarketInfo(Symbol(),MODE_SPREAD))            + " ����� � �������=");
   Print("MODE_STOPLEVEL         " + DoubleToStr(MarketInfo(Symbol(),MODE_STOPLEVEL))         + " ���������� ���������� ������� ����-�����/����-������� � �������=");
   Print("MODE_LOTSIZE           " + DoubleToStr(MarketInfo(Symbol(),MODE_LOTSIZE))           + " ������ ��������� � ������� ������ �����������=");
   Print("MODE_TICKVALUE         " + DoubleToStr(MarketInfo(Symbol(),MODE_TICKVALUE))         + " ������ ������������ ��������� ���� ����������� � ������ ��������=");
   Print("MODE_TICKSIZE          " + DoubleToStr(MarketInfo(Symbol(),MODE_TICKSIZE))          + " ����������� ��� ��������� ���� ����������� � �������="); 
   Print("MODE_SWAPLONG          " + DoubleToStr(MarketInfo(Symbol(),MODE_SWAPLONG))          + " ������ ����� ��� ������� �� �������=");
   Print("MODE_SWAPSHORT         " + DoubleToStr(MarketInfo(Symbol(),MODE_SWAPSHORT))         + " ������ ����� ��� ������� �� �������=");
   Print("MODE_STARTING          " + DoubleToStr(MarketInfo(Symbol(),MODE_STARTING))          + " ����������� ���� ������ ������ (��������)=");
   Print("MODE_EXPIRATION        " + DoubleToStr(MarketInfo(Symbol(),MODE_EXPIRATION))        + " ����������� ���� ��������� ������ (��������)=");
   Print("MODE_TRADEALLOWED      " + DoubleToStr(MarketInfo(Symbol(),MODE_TRADEALLOWED))      + " ���������� ������ �� ���������� �����������=");
   Print("MODE_MINLOT            " + DoubleToStr(MarketInfo(Symbol(),MODE_MINLOT))            + " ����������� ������ ����=");
   Print("MODE_LOTSTEP           " + DoubleToStr(MarketInfo(Symbol(),MODE_LOTSTEP))           + " ��� ��������� ������� ����=");
   Print("MODE_MAXLOT            " + DoubleToStr(MarketInfo(Symbol(),MODE_MAXLOT))            + " ������������ ������ ����=");
   Print("MODE_SWAPTYPE          " + DoubleToStr(MarketInfo(Symbol(),MODE_SWAPTYPE))          + " ����� ���������� ������=");
   Print("MODE_PROFITCALCMODE    " + DoubleToStr(MarketInfo(Symbol(),MODE_PROFITCALCMODE))    + " ������ ������� �������=");
   Print("MODE_MARGINCALCMODE    " + DoubleToStr(MarketInfo(Symbol(),MODE_MARGINCALCMODE))    + " ������ ������� ��������� �������=");
   Print("MODE_MARGININIT        " + DoubleToStr(MarketInfo(Symbol(),MODE_MARGININIT))        + " ��������� ��������� ���������� ��� 1 ����=");
   Print("MODE_MARGINMAINTENANCE " + DoubleToStr(MarketInfo(Symbol(),MODE_MARGINMAINTENANCE)) + " ������ ��������� ������� ��� ��������� �������� ������� � ������� �� 1 ���=");
   Print("MODE_MARGINHEDGED      " + DoubleToStr(MarketInfo(Symbol(),MODE_MARGINHEDGED))      + " �����, ��������� � ���������� ������� � ������� �� 1 ���=");
   Print("MODE_MARGINREQUIRED    " + DoubleToStr(MarketInfo(Symbol(),MODE_MARGINREQUIRED))    + " ������ ��������� �������, ����������� ��� �������� 1 ���� �� �������=");
   Print("MODE_FREEZELEVEL       " + DoubleToStr(MarketInfo(Symbol(),MODE_FREEZELEVEL))       + " ������� ��������� ������� � �������=");
}

