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
   Print("MODE_LOW               " + DoubleToStr(MarketInfo(Symbol(),MODE_LOW))               + " Минимальная дневная цена=");
   Print("MODE_HIGH              " + DoubleToStr(MarketInfo(Symbol(),MODE_HIGH))              + " Максимальная дневная цена=");
   Print("MODE_TIME              " + DoubleToStr(MarketInfo(Symbol(),MODE_TIME))              + " Время поступления последней котировки=");
   Print("MODE_BID               " + DoubleToStr(MarketInfo(Symbol(),MODE_BID))               + " Последняя поступившая цена предложения=");
   Print("MODE_ASK               " + DoubleToStr(MarketInfo(Symbol(),MODE_ASK))               + " Последняя поступившая цена продажи=");
   Print("MODE_POINT             " + DoubleToStr(MarketInfo(Symbol(),MODE_POINT))             + " Размер пункта в валюте котировки=");
   Print("MODE_DIGITS            " + DoubleToStr(MarketInfo(Symbol(),MODE_DIGITS))            + " Количество цифр после запятой в цене инструмента=");
   Print("MODE_SPREAD            " + DoubleToStr(MarketInfo(Symbol(),MODE_SPREAD))            + " Спрэд в пунктах=");
   Print("MODE_STOPLEVEL         " + DoubleToStr(MarketInfo(Symbol(),MODE_STOPLEVEL))         + " Минимально допустимый уровень стоп-лосса/тейк-профита в пунктах=");
   Print("MODE_LOTSIZE           " + DoubleToStr(MarketInfo(Symbol(),MODE_LOTSIZE))           + " Размер контракта в базовой валюте инструмента=");
   Print("MODE_TICKVALUE         " + DoubleToStr(MarketInfo(Symbol(),MODE_TICKVALUE))         + " Размер минимального изменения цены инструмента в валюте депозита=");
   Print("MODE_TICKSIZE          " + DoubleToStr(MarketInfo(Symbol(),MODE_TICKSIZE))          + " Минимальный шаг изменения цены инструмента в пунктах="); 
   Print("MODE_SWAPLONG          " + DoubleToStr(MarketInfo(Symbol(),MODE_SWAPLONG))          + " Размер свопа для ордеров на покупку=");
   Print("MODE_SWAPSHORT         " + DoubleToStr(MarketInfo(Symbol(),MODE_SWAPSHORT))         + " Размер свопа для ордеров на продажу=");
   Print("MODE_STARTING          " + DoubleToStr(MarketInfo(Symbol(),MODE_STARTING))          + " Календарная дата начала торгов (фьючерсы)=");
   Print("MODE_EXPIRATION        " + DoubleToStr(MarketInfo(Symbol(),MODE_EXPIRATION))        + " Календарная дата окончания торгов (фьючерсы)=");
   Print("MODE_TRADEALLOWED      " + DoubleToStr(MarketInfo(Symbol(),MODE_TRADEALLOWED))      + " Разрешение торгов по указанному инструменту=");
   Print("MODE_MINLOT            " + DoubleToStr(MarketInfo(Symbol(),MODE_MINLOT))            + " Минимальный размер лота=");
   Print("MODE_LOTSTEP           " + DoubleToStr(MarketInfo(Symbol(),MODE_LOTSTEP))           + " Шаг изменения размера лота=");
   Print("MODE_MAXLOT            " + DoubleToStr(MarketInfo(Symbol(),MODE_MAXLOT))            + " Максимальный размер лота=");
   Print("MODE_SWAPTYPE          " + DoubleToStr(MarketInfo(Symbol(),MODE_SWAPTYPE))          + " Метод вычисления свопов=");
   Print("MODE_PROFITCALCMODE    " + DoubleToStr(MarketInfo(Symbol(),MODE_PROFITCALCMODE))    + " Способ расчета прибыли=");
   Print("MODE_MARGINCALCMODE    " + DoubleToStr(MarketInfo(Symbol(),MODE_MARGINCALCMODE))    + " Способ расчета залоговых средств=");
   Print("MODE_MARGININIT        " + DoubleToStr(MarketInfo(Symbol(),MODE_MARGININIT))        + " Начальные залоговые требования для 1 лота=");
   Print("MODE_MARGINMAINTENANCE " + DoubleToStr(MarketInfo(Symbol(),MODE_MARGINMAINTENANCE)) + " Размер залоговых средств для поддержки открытых ордеров в расчете на 1 лот=");
   Print("MODE_MARGINHEDGED      " + DoubleToStr(MarketInfo(Symbol(),MODE_MARGINHEDGED))      + " Маржа, взимаемая с перекрытых ордеров в расчете на 1 лот=");
   Print("MODE_MARGINREQUIRED    " + DoubleToStr(MarketInfo(Symbol(),MODE_MARGINREQUIRED))    + " Размер свободных средств, необходимых для открытия 1 лота на покупку=");
   Print("MODE_FREEZELEVEL       " + DoubleToStr(MarketInfo(Symbol(),MODE_FREEZELEVEL))       + " Уровень заморозки ордеров в пунктах=");
}

