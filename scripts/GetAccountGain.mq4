//https://www.mql5.com/ru/code/10358
#define OP_DEPOSIT 6

#define SORTBY     0
#define TICKET     1
#define TYPE       2
#define PROFIT     3
#define OPENTIME   4
#define CLOSETIME  5
#define BALANCE    6
#define GAIN       7

double OrdersTable[][8];

// После создания таблица отсортирована по OPENTIME (по возрастанию) == SortOrdersTable(OPENTIME)
int GetOrdersTable()
{
  int i, Total = OrdersHistoryTotal();
  int Type, Amount = 0;

  ArrayResize(OrdersTable, Total);

  for (i = 0; i < Total; i++)
  {
    OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
    Type = OrderType();

    if ((Type == OP_BUY) || (Type == OP_SELL) || (Type == OP_DEPOSIT))
    {
      OrdersTable[Amount][TICKET] = OrderTicket();
      OrdersTable[Amount][TYPE] = Type;
      OrdersTable[Amount][PROFIT] = OrderProfit() + OrderCommission() + OrderSwap();
      OrdersTable[Amount][OPENTIME] = OrderOpenTime();
      OrdersTable[Amount][CLOSETIME] = OrderCloseTime();

      Amount++;
    }
  }

  ArrayResize(OrdersTable, Amount);

  return(Amount);
}

void SortOrdersTable( int SortBy,  int SortDir = MODE_ASCEND )
{
  int Amount = ArrayRange(OrdersTable, 0);

  for (int i = 0; i < Amount; i++)
    OrdersTable[i][SORTBY] = OrdersTable[i][SortBy];

  ArraySort(OrdersTable, WHOLE_ARRAY, 0, SortDir);

  return;
}

double GetStartBalance()
{
  int Amount = ArrayRange(OrdersTable, 0);
  double Balance = AccountBalance();

  for (int i = 0; i < Amount; i++)
    Balance -= OrdersTable[i][PROFIT];

  Balance = NormalizeDouble(Balance, 2);

  return(Balance);
}

string GetGain()
{
  int i = 0, Amount = ArrayRange(OrdersTable, 0);
  double MaxDD = 1, DD = 1;
  double MaxGain = 1, Gain = 1;
  double Balance = 0;
  string StrTmp = "";

  while (i < Amount)
  {
    if (OrdersTable[i][GAIN] != 0)
    {
      Balance = OrdersTable[i][BALANCE];
      StrTmp = "Period: " + TimeToStr(OrdersTable[i][OPENTIME]) + " - " + TimeToStr(OrdersTable[Amount - 1][CLOSETIME]) + "\n";

      break;
    }

    i++;
  }

  while (i < Amount)
  {
    Gain *= OrdersTable[i][GAIN] + 1;

    if (Gain > MaxGain)
    {
      MaxGain = Gain;

      DD = 1;
    }
    else
      DD *= OrdersTable[i][GAIN] + 1;

    if (DD < MaxDD)
      MaxDD = DD;

    i++;
  }

  Gain -= 1;
  MaxDD = 1 - MaxDD;

  StrTmp = StrTmp + "StartBalance = " + DoubleToStr(Balance, 2) +
                    ", Gain = " + DoubleToStr(100 * Gain, 2) +
                    "%, MaxDrawDown = " + DoubleToStr(100 * MaxDD, 2);

  return(StrTmp);
}

string GetMonthlyGain()
{
  int i = 0, Amount = ArrayRange(OrdersTable, 0);
  static string Months[12] = {"January", "February", "March", "April", "May", "June",
                              "July", "August", "September", "October", "November", "December"};
  double Gain = 1;
  int PrevTime = 0, CurrTime;
  string StrTmp = "";

  while (i < Amount)
  {
    if (OrdersTable[i][GAIN] != 0)
    {
      PrevTime = OrdersTable[i][CLOSETIME];

      break;
    }

    i++;
  }

  while (i < Amount)
  {
    CurrTime = OrdersTable[i][CLOSETIME];

    if (TimeMonth(CurrTime)!= TimeMonth(PrevTime))
    {
      Gain -= 1;

      StrTmp = StrTmp + TimeYear(PrevTime) + " " + Months[TimeMonth(PrevTime) - 1] + " " + DoubleToStr(100 * Gain, 2) + "%\n";

      Gain = 1;

      PrevTime = CurrTime;
    }

    Gain *= OrdersTable[i][GAIN] + 1;

    i++;
  }

  Gain -= 1;

  StrTmp = StrTmp + TimeYear(PrevTime) + " " + Months[TimeMonth(PrevTime) - 1] + " " + DoubleToStr(100 * Gain, 2) + "%";

  return(StrTmp);
}

string GetDailyGain()
{
  int i = 0, Amount = ArrayRange(OrdersTable, 0);
  double AllGain = 1, Gain = 1;
  int PrevTime = 0, CurrTime;
  string StrTmp = "";

  while (i < Amount)
  {
    if (OrdersTable[i][GAIN] != 0)
    {
      PrevTime = OrdersTable[i][CLOSETIME];

      break;
    }

    i++;
  }

  while (i < Amount)
  {
    CurrTime = OrdersTable[i][CLOSETIME];

    if (TimeDay(CurrTime)!= TimeDay(PrevTime))
    {
      AllGain *= Gain;
      Gain -= 1;

      StrTmp = StrTmp + TimeToStr(PrevTime, TIME_DATE) + " " + DoubleToStr(100 * Gain, 2) + "% " + DoubleToStr(100 * (AllGain - 1), 2) + "%\n";

      Gain = 1;

      PrevTime = CurrTime;
    }

    Gain *= OrdersTable[i][GAIN] + 1;

    i++;
  }

  AllGain *= Gain;
  Gain -= 1;

  StrTmp = StrTmp + TimeToStr(PrevTime, TIME_DATE) + " " + DoubleToStr(100 * Gain, 2) + "% " + DoubleToStr(100 * (AllGain - 1), 2) + "%";

  return(StrTmp);
}

void GetAccountGain()
{
  int i = 0, Amount = GetOrdersTable();
  double Balance = GetStartBalance();
  double Profit, BalanceAdd = 0, ProfitAdd = 0;
  bool FlagNegative = FALSE;

  SortOrdersTable(CLOSETIME);

  while (i < Amount)
  {
    OrdersTable[i][BALANCE] = Balance;

    if (Balance >= 0)
      break;

    Balance += OrdersTable[i][PROFIT];
    OrdersTable[i][GAIN] = 0;

    i++;
  }

  while (i < Amount)
  {

    OrdersTable[i][BALANCE] = Balance;
    Profit = OrdersTable[i][PROFIT];

    if (OrdersTable[i][TYPE] == OP_DEPOSIT)
    {
      OrdersTable[i][GAIN] = 0;

      BalanceAdd += Profit;
    }
    else if (Balance + Profit <= 0)
    {
      OrdersTable[i][GAIN] = 0;
      ProfitAdd += Profit;
      FlagNegative = TRUE;
    }
    else
    {
      if (!FlagNegative)
        OrdersTable[i][GAIN] = Profit / Balance;
      else if (BalanceAdd < 0)
        OrdersTable[i][GAIN] = (Profit + ProfitAdd) / (Balance - ProfitAdd - BalanceAdd);
      else
        OrdersTable[i][GAIN] = (Profit + ProfitAdd) / (Balance - ProfitAdd);

      BalanceAdd = 0;
      ProfitAdd = 0;
      FlagNegative = FALSE;
    }

    Balance += Profit;

    i++;
  }

  if (FlagNegative)
  {
    if (BalanceAdd < 0)
    {
      if (Balance - ProfitAdd - BalanceAdd <= 0)
      {
        Alert("Error: Unknown Gain!");

        return;
      }

      OrdersTable[Amount - 1][GAIN] = ProfitAdd / (Balance - ProfitAdd - BalanceAdd);
    }
    else
    {
      if (Balance - ProfitAdd <= 0)
      {
        Alert("Error: Unknown Gain!");

        return;
      }

      OrdersTable[Amount - 1][GAIN] = ProfitAdd / (Balance - ProfitAdd);
    }
  }

  int handle = FileOpen("Acc" + AccountNumber() + "_Gain.txt", FILE_CSV|FILE_WRITE);

  FileWrite(handle, GetGain());

  FileWrite(handle, "\nMonthly Gain:");
  FileWrite(handle, GetMonthlyGain());

  FileWrite(handle, "\nDaily Gain:");
  FileWrite(handle, GetDailyGain());

  FileClose(handle);

  return;
}

void start()
{
  GetAccountGain();

  return;
}