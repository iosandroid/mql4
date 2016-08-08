//https://www.mql5.com/ru/code/10504
#property show_inputs

#define OP_DEPOSIT 6

#define SORTBY     0
#define COMMISSION 1
#define TYPE       2
#define PROFIT     3
#define OPENTIME   4
#define CLOSETIME  5
#define BALANCE    6
#define GAIN       7
#define COMGAIN    8

extern datetime StartTime = D'2011.10.01';
extern double BrokerCommission = 0.5;
extern string FileName = "GainCommission.prn";

double OrdersTable[][9];

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
      if (OrderOpenTime() >= StartTime)
      {
        OrdersTable[Amount][COMMISSION] = -OrderCommission();
        OrdersTable[Amount][TYPE] = Type;
        OrdersTable[Amount][PROFIT] = OrderProfit() + OrderSwap() + OrderCommission();
        OrdersTable[Amount][OPENTIME] = OrderOpenTime();
        OrdersTable[Amount][CLOSETIME] = OrderCloseTime();

        Amount++;
      }
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

void GetGain( double Koef, double &Gain, double &Commission )
{
  double GainTmp;
  double Koef2;
  int i = 0, Amount = ArrayRange(OrdersTable, 0);

  if (Koef != 0)
    Koef2 = 1 - (1 - BrokerCommission) / Koef;

  while (i < Amount)
  {
    if (OrdersTable[i][GAIN] != 0)
      break;

    i++;
  }

  Commission = 0;
  Gain = 1;

  while (i < Amount)
  {
    if (OrdersTable[i][GAIN] != 0)
    {
      GainTmp = OrdersTable[i][GAIN] / (1 + Koef * OrdersTable[i][COMGAIN]);
      Commission += GainTmp * OrdersTable[i][COMGAIN] * Gain;
      Gain *= GainTmp + 1;
    }

    i++;
  }

  Gain -= 1;
  Commission *= Koef * Koef2;

  return;
}

void GetAccountGain()
{
  int i = 0, Amount = GetOrdersTable();
  double Balance = GetStartBalance(), Commission = 0;
  double Profit, BalanceAdd = 0, ProfitAdd = 0, CommissionAdd = 0;
  bool FlagNegative = FALSE;

  SortOrdersTable(CLOSETIME);

  while (i < Amount)
  {
    OrdersTable[i][BALANCE] = Balance;
    OrdersTable[i][BALANCE] += Commission;

    if (Balance >= 0)
      break;

    Balance += OrdersTable[i][PROFIT];
    Commission += OrdersTable[i][COMMISSION];
    OrdersTable[i][GAIN] = 0;
    OrdersTable[i][COMGAIN] = 0;

    i++;
  }

  Commission = 0;

  while (i < Amount)
  {
    OrdersTable[i][BALANCE] = Balance;
    Profit = OrdersTable[i][PROFIT];
    Commission += OrdersTable[i][COMMISSION];

    if (OrdersTable[i][TYPE] == OP_DEPOSIT)
    {
      OrdersTable[i][GAIN] = 0;
      OrdersTable[i][COMGAIN] = 0;

      BalanceAdd += Profit;
    }
    else if (Balance + Profit <= 0)
    {
      OrdersTable[i][GAIN] = 0;
      OrdersTable[i][COMGAIN] = 0;

      ProfitAdd += Profit;
      CommissionAdd += Commission;
      FlagNegative = TRUE;
    }
    else
    {
      if (!FlagNegative)
      {
        OrdersTable[i][GAIN] = (Profit + Commission) / Balance;

        if (Profit != 0)
        {
          OrdersTable[i][COMGAIN] = Commission / Profit;
          Commission = 0;
        }
        else
          OrdersTable[i][COMGAIN] = 0;
      }
      else if (BalanceAdd < 0)
      {
        OrdersTable[i][GAIN] = (Profit + ProfitAdd + Commission) / (Balance - ProfitAdd - BalanceAdd);

        if (Profit + ProfitAdd != 0)
        {
          OrdersTable[i][COMGAIN] = Commission / (Profit + ProfitAdd);
          Commission = 0;
        }
        else
          OrdersTable[i][COMGAIN] = 0;
      }
      else
      {
        OrdersTable[i][GAIN] = (Profit + ProfitAdd + Commission) / (Balance - ProfitAdd);

        if (Profit + ProfitAdd != 0)
        {
          OrdersTable[i][COMGAIN] = Commission / (Profit + ProfitAdd);
          Commission = 0;
        }
        else
          OrdersTable[i][COMGAIN] = 0;
      }

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

      OrdersTable[Amount - 1][GAIN] = (ProfitAdd + Commission) / (Balance - ProfitAdd - BalanceAdd);
    }
    else
    {
      if (Balance - ProfitAdd <= 0)
      {
        Alert("Error: Unknown Gain!");

        return;
      }

      OrdersTable[Amount - 1][GAIN] = (ProfitAdd + Commission) / (Balance - ProfitAdd);
    }
  }

  return;
}

void start()
{
  double MaxCommission = -1, MaxGain;
  double Gain, Commission;
  double GainInit, CommissionInit;
  int MaxI, handle = FileOpen(FileName, FILE_CSV|FILE_WRITE);

  GetAccountGain();

  GetGain(1, GainInit, CommissionInit);

  for (int i = 0; i < 200; i++)
  {
    GetGain(i / 100.0, Gain, Commission);

    Gain /= GainInit;
    Commission /= CommissionInit;

    if (Commission > MaxCommission)
    {
      MaxCommission = Commission;
      MaxGain = Gain;
      MaxI = i;
    }

    FileWrite(handle, DoubleToStr(Gain, 8) + " " + DoubleToStr(Commission, 8));
  }

  FileClose(handle);

  MessageBox("Optimal Broker Commission is " + MaxI + "% of current commission.\n" +
             "Summary Commission is " + DoubleToStr(100 * MaxCommission, 2) + "% of current commission.\n" +
             "Gain is " + DoubleToStr(100 * MaxGain, 2) + "% of current gain.\n" +
             "See details in " + FileName + " file.");

  return;
}