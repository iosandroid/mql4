//+------------------------------------------------------------------+
//|                                              NamedPipeServer.mq4 |
//|                              Copyright © 2010 MTIntelligence.com |
//|                                    http://www.mtintelligence.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2010 MTIntelligence.com"
#property link      "http://www.mtintelligence.com"




// *********************************************************************************************
//
//  MT4 named-pipe server for receiving messages from the NamedPipeClient.mqh client code (or
//  from anything else which can send data over named pipes). Allows communication - on an
//  asynchronous basis - between different MT4 instances on the same computer.
//  The messages are simply strings: the format and meaning of them is up to you and your code.
//  Requires the sender/client to know the "name" being used by the listener/server. This method
//  does not allow broadcasting on the off-chance that something happens to be listening for messages.
//
//  See the ExampleNamedPipeServerEA example of a message receiver, and the
//  ExampleNamedPipeSenderScript example of a message sender.
//
//  You simply do a CreatePipeServer() during your init(), and a DestroyPipeServer() during
//  your deinit(). You then check for messages on every tick, in start(), using the
//  CheckForPipeMessages() function. This returns an array of all the messages which have
//  been received since the last call to CheckForPipeMessages().
//
//  The server needs to give itself a name (e.g. the MT4 account number) which you specify
//  as the first parameter for CreatePipeServer(). Clients need to use this same name when sending
//  messages to the server.
//
//  There is a limit on the number of messages which the server can receive per tick. This defaults
//  to DEFAULT_MAX_PIPES, but can be altered using the optional second parameter for the
//  CreatePipeServer() function. If more messages than this are sent between each call by the server
//  to CheckForPipeMessages(), then the extra messages will fail, and the client(s) will need to
//  retry their send.
//
//  N.B. Requires "Allow DLL Imports" to be turned on
//
//  N.B, again: this is not the recommended way of using named pipes. The normal way is to
//  have a multi-threaded server or overlapped I/O, but neither is possible in MT4.
//
//  And N.B. again: unlike the MT5 code at http://www.mql5.com/en/articles/115, this does not
//  use an infinite loop in start() in order to listen for messages. That method solves the
//  issue of too many messages being sent between each call to CheckForPipeMessages(), but
//  raises another issue in that ConnectNamedPipe() is a blocking call, and the EA/script
//  has to be forcibly terminated rather than exiting gracefully when the EA/script is
//  removed from its chart. The method used here does not allow anything like the same
//  message volumes as the MT5 version, but is non-blocking, and doesn't assume a constant
//  connection between the sender and receiver.
//
// *********************************************************************************************





// *********************************************************************************************
// Private constants used by the pipe server
// *********************************************************************************************

// Number of pipe instances to create by default. This value can overridden by the optional parameter to
// CreatePipeServer(). The number of instances is in effect the maximum number of messages which
// can be sent to the server between each call which the server makes to CheckForPipeMessages().
// If more messages than this are sent, the extra messages will fail and the sender(s) will need to retry.

// #define DEFAULT_MAX_PIPES  80
#define DEFAULT_MAX_PIPES  1 // PriceGiver sends to the PriceTaker only one fresh (actual) message.

// Base name to use for pipe creation
#define PIPE_BASE_NAME     "\\\\.\\pipe\\mt4-"     // MUST tally with client code



// *********************************************************************************************
// DLL imports and associated constants used by the pipe server
// *********************************************************************************************

#define GENERIC_READ                   0x80000000
#define GENERIC_WRITE                  0x40000000
#define PIPE_ACCESS_DUPLEX             3
#define PIPE_UNLIMITED_INSTANCES       255
#define PIPE_NOWAIT                    1
#define PIPE_TYPE_MESSAGE              4
#define PIPE_READMODE_MESSAGE          2
#define PIPE_WAIT                      0

#import "kernel32.dll"
   int CreateNamedPipeA(string pipeName,int openMode,int pipeMode,int maxInstances,int outBufferSize,int inBufferSize,int defaultTimeOut,int security);
   int PeekNamedPipe(int PipeHandle, int PassAsZero, int PassAsZero2, int PassAsZero3, int & BytesAvailable[], int PassAsZero4);
   int CreateFileA(string Filename, int AccessMode, int ShareMode, int PassAsZero, int CreationMode, int FlagsAndAttributes, int AlsoPassAsZero);
   int CloseHandle(int fileHandle);
   int ReadFile(int FileHandle, int BufferPtr, int BufferLength, int & BytesRead[], int PassAsZero);
   int MulDiv(string X, int N1, int N2);
#import


// *********************************************************************************************
// Global variables used by the pipe server
// *********************************************************************************************

// Number of pipe instances to allocate. Defaults to DEFAULT_MAX_PIPES unless it is overridden
// by the optional parameter to CreatePipeServer()
int glbPipeCount = DEFAULT_MAX_PIPES;

// Array of pipe handles allocated by CreatePipeServer()
int glbPipe[DEFAULT_MAX_PIPES];

// Persistent storage of the pipe name passed as a parameter to CreatePipeServer()
string glbPipeName;


// *********************************************************************************************
// Creates the pipe server. Used in init()
// *********************************************************************************************

// Starts the pipe server by creating n instances of the pipe, where n defaults to
// DEFAULT_MAX_PIPES but can be overridden
void CreatePipeServer(string PipeName, int UsePipeInstances = DEFAULT_MAX_PIPES)
{
   // Store the number of pipe instances to use and resize the array accordinging
   glbPipeCount = UsePipeInstances;
   ArrayResize(glbPipe, glbPipeCount);

   // Store the name to use for the pipe instances
   glbPipeName = PipeName;

   // Create the pipe instances
   for (int i = 0; i < glbPipeCount; i++) {
      glbPipe[i] = CreatePipeInstance();
   }

   return;
}


// *********************************************************************************************
// Frees the resources of the pipe server. Used in deinit()
// *********************************************************************************************

// Closes all the resources used by the pipe server: i.e. closes all the pipe instances
void DestroyPipeServer()
{
   for (int i = 0; i < glbPipeCount; i++) {
      CloseHandle(glbPipe[i]);
   }
   return;
}

// *********************************************************************************************
// Checks for new messages. Used in start()
// *********************************************************************************************

// Checks for new messages. The return value is the number of messages received since the last check,
// and the array is resized to contain the incoming messages
int CheckForPipeMessages(string & arrMessages[])
{
   int MessagesFound = 0;

   for (int i = 0; i < glbPipeCount; i++) {
      // Check each pipe instance for a message
      string strMsg = CheckPipe(i);
      if (strMsg != "") {

         // If there is a message, add it to the list which we're passing back
         MessagesFound++;
         ArrayResize(arrMessages, MessagesFound);
         arrMessages[MessagesFound - 1] = strMsg;
      }
   }

   return (MessagesFound);
}


// Function which checks to see if a message has come in on a pipe instance. If so, the message
// is retrieved, and the pipe instance is "freed" by destroying and recreating it
string CheckPipe(int PipeIndex)
{
   string strReturnValue = "";

   // See if there's data available on the pipe
   int BytesAvailable[1] = {0};
   int res = PeekNamedPipe(glbPipe[PipeIndex], 0, 0, 0, BytesAvailable, 0);
   if (res != 0) {
      // PeekNamedPipe() succeeded

      // Is there data?
      if (BytesAvailable[0] != 0) {

         // Keep reading until either we have all the data, or an error occurs
         int TotalBytesRead = 0;
         while (TotalBytesRead < BytesAvailable[0]) {

            // Allocate a 200-byte buffer
            string ReadBuffer = "01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789";
            int BufferLength = StringLen(ReadBuffer);

            // Read up to the maximum buffer size from the pipe. (The use of MulDiv() is an old trick from VB6 days for
            // getting the address in memory of a string variable.)
            int BytesRead[1] = {0};
            ReadFile(glbPipe[PipeIndex], MulDiv(ReadBuffer, 1, 1), BufferLength, BytesRead, 0);

            // Did we get any data from the read?
            if (BytesRead[0] > 0) {
               // Yes, got some data. Add it to the total message which is passed back
               strReturnValue = StringConcatenate(strReturnValue, StringSubstr(ReadBuffer, 0, BytesRead[0]));
               TotalBytesRead += BytesRead[0];
            } else {
               // No, the read failed. Stop reading, and pass back an empty string
               strReturnValue = "";
               TotalBytesRead = 999999;
            }
         }

         // Destroy and recreate the pipe instance
         CloseHandle(glbPipe[PipeIndex]);
         glbPipe[PipeIndex] = CreatePipeInstance();

      } else {
         // No data available on pipe
      }
   } else {
      // PeekNamedPipe() failed
   }

   return (strReturnValue);
}

// Service function which creates a pipe instance
int CreatePipeInstance()
{
   string strPipeName = StringConcatenate(PIPE_BASE_NAME , glbPipeName);
   return (CreateNamedPipeA(strPipeName, GENERIC_READ | PIPE_ACCESS_DUPLEX, PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_NOWAIT, PIPE_UNLIMITED_INSTANCES, 1000, 1000, 0, NULL));
}