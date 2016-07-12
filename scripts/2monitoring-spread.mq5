
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots	 3
#property indicator_type1 DRAW_HISTOGRAM
#property indicator_type2 DRAW_HISTOGRAM
#property indicator_type3 DRAW_HISTOGRAM
#property indicator_color1 clrGray
#property indicator_color2 clrRed
#property indicator_color3 clrGold
#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 2
#property indicator_minimum -1

double MaxSpread[], AvgSpread[], MinSpread[];
int MinSp, MaxSp, Vol; datetime PrevTime;
double AvgSp, Ask, Bid;
string FileName;
bool Flag;

//------------------------------------------------------------------	RealSymbol
bool RealSymbol(string smb) { return(SymbolInfoDouble(smb, SYMBOL_BID)!=0); }
//------------------------------------------------------------------	init
int OnInit()
{
	SetIndexBuffer(0, MaxSpread, INDICATOR_DATA); PlotIndexSetString(0, PLOT_LABEL, "Max"); ArraySetAsSeries(MaxSpread, true); 
	SetIndexBuffer(1, AvgSpread, INDICATOR_DATA); PlotIndexSetString(1, PLOT_LABEL, "Avg"); ArraySetAsSeries(AvgSpread, true); 
	SetIndexBuffer(2, MinSpread, INDICATOR_DATA); PlotIndexSetString(2, PLOT_LABEL, "Min"); ArraySetAsSeries(MinSpread, true); 
  Flag=RealSymbol(Symbol());
  FileName=Symbol()+EnumToString(Period())+"_Spread.dat";
	return(0);
}
//------------------------------------------------------------------	OnDeinit
void OnDeinit(const int reason) { if (Flag) WriteSpread(); }
//------------------------------------------------------------------	OnCalculate
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
  Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
  Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
  ArraySetAsSeries(time, true);

  if (!Flag) { GetData(); return(rates_total); } // если символ существует, то пытаемся прочитать прежние данные из файла

  static bool FirstRun=true; // флаг первого запуска
  if (FirstRun) { GetData(); CreateNewSpread(); PrevTime=time[0]; FirstRun=false; return(rates_total); } // если это первый запуск, то читаем из файла

  if (PrevTime==time[0]) { ModifySpread(); PrevTime=time[0]; }// если этот бар уже внесли в файл, то просто обновляем спред
  else { WriteSpread(); CreateNewSpread(); PrevTime=time[0]; } // если бар новый, то сохраняем его и сдвигаем бары влево
	
	// обновляем даные текущего бара
  MaxSpread[0]=MaxSp;
  AvgSpread[0]=AvgSp/Vol;
  MinSpread[0]=MinSp;
	return(rates_total);
}
//------------------------------------------------------------------	CreateNewSpread
void CreateNewSpread() // задали начальное значение спреда
{
	MinSp=int((Ask-Bid)/Point()+0.1);
	MaxSp=MinSp;
	AvgSp=MinSp;
	Vol=1;
}
//------------------------------------------------------------------	ModifySpread
void ModifySpread() // обновляем текущие значения спреда
{
	int Spread=int((Ask-Bid)/Point()+0.1);
	if (Spread>MaxSp) MaxSp=Spread; else if (Spread<MinSp) MinSp=Spread;
	AvgSp+=Spread; Vol++;
}
//------------------------------------------------------------------	GetData
void GetData() // читаем спреды из файла
{
	int h=FileOpen(FileName, FILE_BIN|FILE_READ|FILE_ANSI); if (h<0) return;
	while(!FileIsEnding(h))
	{
		datetime dt=(datetime)FileReadLong(h);
		double Max=FileReadDouble(h);
		double Avg=FileReadDouble(h);
		double Min=FileReadDouble(h);
		int i=(int)iBarShift(Symbol(), Period(), dt, true);
		if (i>=0) { MaxSpread[i]=Max; AvgSpread[i]=Avg; MinSpread[i]=Min; }
	}
	FileClose(h);
}
//----------------------------------------------------------------	WriteSpread
void WriteSpread() // дописываем в файл
{
  int h=FileOpen(FileName, FILE_BIN|FILE_READ|FILE_WRITE|FILE_ANSI);
  AvgSp/=Vol; // усреднили на объем
  FileSeek(h, 0, SEEK_END);
  FileWriteLong(h, PrevTime);
  FileWriteDouble(h, MaxSp);
  FileWriteDouble(h, AvgSp);
  FileWriteDouble(h, MinSp);
  FileClose(h);
}
//----------------------------------------------------------------	iBarShift
long iBarShift(string smb, ENUM_TIMEFRAMES tf, datetime time, bool exac=false)
{
  datetime rates[]; if(time<0) return(-1);
  int bar=CopyTime(smb, tf, iTime(smb, tf, 0), time, rates); if (bar<=0) return(-1);
  if (exac && iTime(smb, tf, bar-1)!=time) return(-1);
  return(bar-1);
}
//---------------------------------------------------------------   iTime
datetime iTime(string smb, ENUM_TIMEFRAMES tf, int i)
{
	datetime rates[]; if(i<0) return(-1); 
	if (CopyTime(smb, tf, i, 1, rates)>0) return(rates[0]);
	return(-1);
}
