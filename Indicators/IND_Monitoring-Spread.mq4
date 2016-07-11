#property indicator_separate_window
#property indicator_buffers 3
#property indicator_color1 Blue
#property indicator_color2 Lime
#property indicator_color3 Red
#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 2
#property indicator_minimum -1

double MaxSpread[], AvgSpread[], MinSpread[];
bool Flag;

int MinSp, MaxSp, Vol, PrevTime;
double AvgSp;
string FileName;

bool RealSymbol( string Str )
{
  return(MarketInfo(Str, MODE_BID) != 0);
}

void init()  
{   
  int i;
   
  SetIndexBuffer(0, MaxSpread);
  SetIndexStyle(0, DRAW_HISTOGRAM); 
   
  SetIndexBuffer(1, AvgSpread);
  SetIndexStyle(1, DRAW_HISTOGRAM);
   
  SetIndexBuffer(2, MinSpread);
  SetIndexStyle(2, DRAW_HISTOGRAM);

  for (i = 0; i <= 8; i++)
   SetLevelValue(i, i * 10);
   
  Flag = RealSymbol(Symbol());
  FileName = Symbol() + Period() + "_Spread.dat";
         
 return;  
}

void GetData()
{
  double Min, Avg, Max;
  int T, i;
  int handle = FileOpen(FileName, FILE_BIN|FILE_READ);
  
  if (handle < 0)
    return;

  while (!FileIsEnding(handle))
  {
    T = FileReadInteger(handle);     
    Max = FileReadDouble(handle);
    Avg = FileReadDouble(handle);
    Min = FileReadDouble(handle);
      
    i = iBarShift(Symbol(), Period(), T, TRUE);
    
    if (i >= 0)
    {
      MaxSpread[i] = Max;
      AvgSpread[i] = Avg;
      MinSpread[i] = Min;
    }
  }
  
  FileClose(handle);
  
  return; 
}

void CreateNewSpread()
{
  MinSp = (Ask - Bid) / Point + 0.1;
  MaxSp = MinSp;
  AvgSp = MinSp;
  Vol = 1;
  PrevTime = Time[0];
  
  return;
}

void ModifySpread()
{
  int Spread = (Ask - Bid) / Point + 0.1;
  
  if (Spread > MaxSp)
    MaxSp = Spread;
  else if (Spread < MinSp)
    MinSp = Spread;
    
  AvgSp += Spread;
  Vol++;
  
  PrevTime = Time[0];
  
  return;
}

void WriteSpread()
{
  int handle = FileOpen(FileName, FILE_BIN|FILE_READ|FILE_WRITE);
  
  AvgSp /= Vol;
  
  FileSeek(handle, 0, SEEK_END);
  FileWriteInteger(handle, PrevTime);
  FileWriteDouble(handle, MaxSp);
  FileWriteDouble(handle, AvgSp);
  FileWriteDouble(handle, MinSp);
  
  FileClose(handle);

  return;  
}

void deinit()
{
  if (Flag)
    WriteSpread();
  
  return;
}

void start()  
{       
  static bool FirstRun = TRUE;
  
  if (!Flag)
  {
    GetData();
    
    return;
  }
  
  if (FirstRun)
  {
    GetData();
    CreateNewSpread();
    
    FirstRun = FALSE;
    
    return;
  }

  if (PrevTime == Time[0])
    ModifySpread();
  else
  {
    WriteSpread();
    
    CreateNewSpread();
  }
    
  MaxSpread[0] = MaxSp;
  AvgSpread[0] = AvgSp / Vol;
  MinSpread[0] = MinSp;
   
  return;  
}

