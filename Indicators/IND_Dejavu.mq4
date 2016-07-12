#property indicator_chart_window
#property indicator_buffers 5
#property indicator_color1 Red
#property indicator_color2 Blue
#property indicator_color3 Blue
#property indicator_color4 Magenta
#property indicator_color5 Magenta
#property indicator_width1 2
#property indicator_width2 1
#property indicator_width3 1
#property indicator_width4 1
#property indicator_width5 1

extern bool StDev = FALSE;
extern bool HighLow = FALSE;

#define AMOUNT_DATA 5

double Buffer[], BufferHigh[], BufferLow[], BufferHigh2[], BufferLow2[];

void init()
{
  SetIndexBuffer(0, Buffer);
  SetIndexStyle(0, DRAW_LINE);

  SetIndexBuffer(1, BufferHigh);
  SetIndexStyle(1, DRAW_LINE);

  SetIndexBuffer(2, BufferLow);
  SetIndexStyle(2, DRAW_LINE);

  SetIndexBuffer(3, BufferHigh2);
  SetIndexStyle(3, DRAW_LINE);

  SetIndexBuffer(4, BufferLow2);
  SetIndexStyle(4, DRAW_LINE);

  return;
}

void start()
{
  int i, time, Pos, Shift = 0;
  double Data[], DataHigh[], DataLow[], DataHigh2[], DataLow2[];
  int Positions[];
  int handle = FileOpen(WindowHandle(Symbol(), Period()) + "i.dat", FILE_READ|FILE_BIN);
  int Size = FileSize(handle) / (LONG_VALUE + DOUBLE_VALUE * AMOUNT_DATA);

  ArrayResize(Data, Size);
  ArrayResize(DataHigh, Size);
  ArrayResize(DataLow, Size);
  ArrayResize(DataHigh2, Size);
  ArrayResize(DataLow2, Size);
  ArrayResize(Positions, Size);

  for (i = 0; i < Size; i++)
  {
    time = FileReadInteger(handle);

    if (time >= 0)
    {
      Pos = iBarShift(Symbol(), Period(), time);
    }
    else
    {
      Pos--;

      if (Pos < 0)
        Shift++;
    }

    Positions[i] = Pos;

    Data[i] = FileReadDouble(handle);
    DataHigh[i] = FileReadDouble(handle);
    DataLow[i] = FileReadDouble(handle);
    DataHigh2[i] = FileReadDouble(handle);
    DataLow2[i] = FileReadDouble(handle);
  }

  FileClose(handle);

  ArrayInitialize(Buffer, EMPTY_VALUE);
  ArrayInitialize(BufferHigh, EMPTY_VALUE);
  ArrayInitialize(BufferLow, EMPTY_VALUE);
  ArrayInitialize(BufferHigh2, EMPTY_VALUE);
  ArrayInitialize(BufferLow2, EMPTY_VALUE);

  for (i = 0; i < AMOUNT_DATA; i++)
    SetIndexShift(i, Shift);

  for (i = 0; i < Size; i++)
  {
    Pos = Positions[i] + Shift;
    Buffer[Pos] = Data[i];

    if (StDev)
    {
      BufferHigh[Pos] = DataHigh[i];
      BufferLow[Pos] = DataLow[i];
    }

    if (HighLow)
    {
      BufferHigh2[Pos] = DataHigh2[i];
      BufferLow2[Pos] = DataLow2[i];
    }
  }

  return;
}