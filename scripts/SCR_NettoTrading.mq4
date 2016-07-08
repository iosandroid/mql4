//https://www.mql5.com/ru/code/9275
#property show_inputs

#define PAUSE 100
#define MAX_SYMBOLS 100

extern bool AntiSwap = FALSE;
extern int SizeColumn = 20;

string StrToColumn( string Str, int Length )
{
  Length -= StringLen(Str);
  
  while (Length > 0)
  {
    Str = " " + Str;
    Length--;
  }
  
  return(Str);
}
 
int GetSymbols( string& Symbols[] )
{
  int i, Amount = 0;
  int Pos, Total = OrdersTotal();
  
  for (Pos = 0; Pos < Total; Pos++)
  {
    OrderSelect(Pos, SELECT_BY_POS);
    
    if ((OrderType() == OP_BUY) || (OrderType() == OP_SELL))
    {
      i = 0;
      
      while (i < Amount)
      {
        if (OrderSymbol() == Symbols[i])
          break;
          
        i++;
      }
          
      if (i == Amount)
      {
        Symbols[i] = OrderSymbol();
        Amount++;
      }
    }
  }
  
  return(Amount);
}

void GetSymbolTempData( string inSymbol, double& VolBuy, double& VolSell, double& ProfitBuy, double& ProfitSell, double& ComissionValue )
{
  int Pos, Total = OrdersTotal();

  VolBuy = 0;
  VolSell = 0;
  ProfitBuy = 0;
  ProfitSell = 0;
  ComissionValue = 0;
  
  for (Pos = 0; Pos < Total; Pos++)
  {
    OrderSelect(Pos, SELECT_BY_POS);
    
    if (OrderSymbol() == inSymbol)
    {
      if (OrderType() == OP_BUY)
      {
        ProfitBuy += OrderOpenPrice() * OrderLots();
        VolBuy += OrderLots();
        ComissionValue = OrderCommission() /OrderLots();
      }
      else if (OrderType() == OP_SELL)
      {
        ProfitSell += OrderOpenPrice() * OrderLots();
        VolSell += OrderLots();
        ComissionValue = OrderCommission() / OrderLots();
      }
    }
  }
    
  return;
}

double GetSymbolVolume( string inSymbol )
{
  double VolBuy,  VolSell, ProfitBuy, ProfitSell, ComissionValue;
  
  GetSymbolTempData(inSymbol, VolBuy, VolSell, ProfitBuy, ProfitSell, ComissionValue);
  
  return(VolBuy - VolSell);
}

double GetSymbolOpenPrice( string inSymbol )
{
  double SymbolOpenPrice = 0;
  double VolBuy,  VolSell, ProfitBuy, ProfitSell, ComissionValue;
  
  GetSymbolTempData(inSymbol, VolBuy, VolSell, ProfitBuy, ProfitSell, ComissionValue);

  
  if (NormalizeDouble(VolBuy - VolSell, 2) != 0)
  {
    if (VolBuy > VolSell)
      SymbolOpenPrice = ProfitBuy / VolBuy;
    else
      SymbolOpenPrice = ProfitSell / VolSell;
  }
  
  return(SymbolOpenPrice);
}

double GetSymbolProfit( string inSymbol )
{
  double Vol, SymbolProfit = 0;
  double VolBuy,  VolSell, ProfitBuy, ProfitSell, ComissionValue;
  
  GetSymbolTempData(inSymbol, VolBuy, VolSell, ProfitBuy, ProfitSell, ComissionValue);
  
  Vol = VolBuy - VolSell;
  
  if (Vol > 0)
    SymbolProfit = (MarketInfo(inSymbol, MODE_BID) - ProfitBuy / VolBuy) * Vol;
  else
    SymbolProfit = (MarketInfo(inSymbol, MODE_ASK) - ProfitSell / VolSell) * Vol;

  SymbolProfit *= MarketInfo(inSymbol, MODE_TICKVALUE) / MarketInfo(inSymbol, MODE_POINT);
  
  if (Vol > 0)
    SymbolProfit += Vol * ComissionValue;
  else
    SymbolProfit -= Vol * ComissionValue;
  
  return(SymbolProfit);
}

double GetSymbolProfitForEquity( string inSymbol )
{
  double Vol, SymbolProfit;
  double VolBuy,  VolSell, ProfitBuy, ProfitSell, ComissionValue;
  
  GetSymbolTempData(inSymbol, VolBuy, VolSell, ProfitBuy, ProfitSell, ComissionValue);
  
  SymbolProfit = ProfitSell - ProfitBuy;
  Vol = VolBuy - VolSell;
  
  if (Vol > 0)
    SymbolProfit += MarketInfo(inSymbol, MODE_BID) * Vol;
  else
    SymbolProfit += MarketInfo(inSymbol, MODE_ASK) * Vol;

  SymbolProfit *= MarketInfo(inSymbol, MODE_TICKVALUE) / MarketInfo(inSymbol, MODE_POINT);
  
  if (Vol > 0)
    SymbolProfit += VolBuy * ComissionValue;
  else
    SymbolProfit += VolSell * ComissionValue;
  
  return(SymbolProfit);
}

double GetEquity()
{
  string Symbols[MAX_SYMBOLS];
  int AmountSymbols;
  int i;
  double ProfitForEquity = 0;

  AmountSymbols = GetSymbols(Symbols);
  
  for (i = 0; i < AmountSymbols; i++)
    ProfitForEquity += GetSymbolProfitForEquity(Symbols[i]);
    
  return(AccountBalance() + ProfitForEquity);
}

double GetSymbolProfitForBalance( string inSymbol )
{
  double Vol, SymbolProfit;
  double VolBuy,  VolSell, ProfitBuy, ProfitSell, ComissionValue;
  
  GetSymbolTempData(inSymbol, VolBuy, VolSell, ProfitBuy, ProfitSell, ComissionValue);
  
  SymbolProfit = ProfitSell - ProfitBuy;
  Vol = VolBuy - VolSell;
  
  if (NormalizeDouble(Vol, 2) != 0)
  {
    if (Vol > 0)
      SymbolProfit += Vol * ProfitBuy / VolBuy;
    else
      SymbolProfit += Vol * ProfitSell / VolSell;
  }

  SymbolProfit *= MarketInfo(inSymbol, MODE_TICKVALUE) / MarketInfo(inSymbol, MODE_POINT);
  
  if (Vol > 0)
    SymbolProfit += VolSell* ComissionValue;
  else
    SymbolProfit += VolBuy * ComissionValue;
  
  return(SymbolProfit);
}

double GetBalance()
{
  string Symbols[MAX_SYMBOLS];
  int AmountSymbols;
  int i;
  double ProfitForBalance = 0;

  AmountSymbols = GetSymbols(Symbols);
  
  for (i = 0; i < AmountSymbols; i++)
    ProfitForBalance += GetSymbolProfitForBalance(Symbols[i]);
    
  return(AccountBalance() + ProfitForBalance);
}

double GetSymbolLastTime( string inSymbol )
{
  double LastTime = 0;
  int Pos, Total = OrdersTotal();
  
   for (Pos = 0; Pos < Total; Pos++)
   {
     OrderSelect(Pos, SELECT_BY_POS);
    
     if (OrderSymbol() == inSymbol)
       if ((OrderType() == OP_BUY) || (OrderType() == OP_SELL))
         if (OrderOpenTime() > LastTime)
           LastTime = OrderOpenTime();
   }
  
  return(LastTime);
}

string GetInfoSymbol( string inSymbol )
{
  double Vol;
  int Dig;
  string Str = "";
  
  Vol = GetSymbolVolume(inSymbol);
  
  if (NormalizeDouble(Vol, 2) != 0)
  {
    Dig = MarketInfo(inSymbol, MODE_DIGITS);
        
    Str = Str + StrToColumn(inSymbol, SizeColumn);
    Str = Str + StrToColumn(TimeToStr(GetSymbolLastTime(inSymbol)), SizeColumn);
    
    if (Vol > 0)
    {
      Str = Str + StrToColumn("buy", SizeColumn);
      Str = Str + StrToColumn(DoubleToStr(Vol, 2), SizeColumn);
    }
    else
    {
      Str = Str + StrToColumn("sell", SizeColumn);
      Str = Str + StrToColumn(DoubleToStr(-Vol, 2), SizeColumn);
    }

    Str = Str + StrToColumn(DoubleToStr(GetSymbolOpenPrice(inSymbol), Dig), SizeColumn);
    
    if (Vol > 0)
      Str = Str + StrToColumn(DoubleToStr(MarketInfo(inSymbol, MODE_BID), Dig), SizeColumn);
    else
      Str = Str + StrToColumn(DoubleToStr(MarketInfo(inSymbol, MODE_ASK), Dig), SizeColumn);
  
    Str = Str + StrToColumn(DoubleToStr(GetSymbolProfit(inSymbol), 2), SizeColumn);
  }
  
  return(Str);
}

int GetOrderTicket( string inSymbol, int Type )
{
  int Pos, Total = OrdersTotal();
  
  for (Pos = 0; Pos < Total; Pos++)
  {
    OrderSelect(Pos, SELECT_BY_POS);
    
    if (OrderSymbol() == inSymbol)
      if (OrderType() == Type)
        return(OrderTicket());
  }
  
  return(-1);
}

void LockOFF( string inSymbol )
{
  int BuyTicket, SellTicket;
    
  BuyTicket = GetOrderTicket(inSymbol, OP_BUY);
  SellTicket = GetOrderTicket(inSymbol, OP_SELL);
  
  while ((BuyTicket != -1) && (SellTicket != -1))
  {
    OrderCloseBy(BuyTicket, SellTicket);

    BuyTicket = GetOrderTicket(inSymbol, OP_BUY);
    SellTicket = GetOrderTicket(inSymbol, OP_SELL);
  }
  
  return;
}

void deinit()
{
  Comment("");
  
  return;
}

void start()
{
  string Symbols[MAX_SYMBOLS];
  int AmountSymbols;
  int i;
  string StrOut, Str;
  string StrInit;
  
  StrInit = StrToColumn("Symbol", SizeColumn) + StrToColumn("Time", SizeColumn) + StrToColumn("Type", SizeColumn) +
            StrToColumn("Volume", SizeColumn) + StrToColumn("OpenPrice", SizeColumn) + StrToColumn("ClosePrice", SizeColumn) +
            StrToColumn("Profit", SizeColumn);
  

  while (!IsStopped())
  {
    AmountSymbols = GetSymbols(Symbols);
    StrOut = StrInit;
    
    for (i = 0; i < AmountSymbols; i++)
    {
      if (AntiSwap)
        LockOFF(Symbols[i]);

      Str = GetInfoSymbol(Symbols[i]);
      
      if (Str != "")
        StrOut = StrOut + "\n" + Str;
    }
    
    StrOut = StrOut + "\n\nBalance: " + DoubleToStr(GetBalance(), 2) + " Equity: " + DoubleToStr(GetEquity(), 2);
    
    Comment(StrOut);
    
    Sleep(PAUSE);
    RefreshRates();
  }
  
  return;
}