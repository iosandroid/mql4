//+------------------------------------------------------------------+
//|                                              NamedPipeClient.mq4 |
//|                              Copyright © 2010 MTIntelligence.com |
//|                                    http://www.mtintelligence.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2010 MTIntelligence.com"
#property link      "http://www.mtintelligence.com"



// *********************************************************************************************
//
//  MT4 named-pipe client for sending messages to the NamedPipeServer.mqh code. Allows
//  communication - on an asynchronous basis - between different MT4 instances on the same computer.
//  The messages are simply strings: the format and meaning of them is up to you and your code.
//  Requires the sender/client to know the "name" being used by the listener/server. This method
//  does not allow broadcasting on the off-chance that something happens to be listening for messages.
//
//  See the ExampleNamedPipeServerEA example of a message receiver, and the
//  ExampleNamedPipeSenderScript example of a message sender.
//
//  The sender simply calls SendPipeMessage(), specifying the server name to send to, and the
//  message to send. The "name" is simply whatever the server code has used in its call
//  to the CreatePipeServer() function. The SendPipeMessage() function returns true or false
//  indicating whether the message succeeded.
//
//  Message transmission is aynchronous. Successful sending does not imply that the message
//  has yet been processed by the server.
//
//  Please note that messages can fail for three reasons (and, unfortunately, it's not
//  possible to distinguish between them):
//
//     1. The server simply isn't running
//     2. The server is running, but the "name" parameter being used by the client is wrong.
//     3. The server has received too many pending messages.
//
//  There is a limit on the number of messages which the server can receive between each tick
//  (or, more strictly speaking, between each call which is made to its CheckForPipeMessages()
//  function). If the server can accept a maximum of 10 pending messages, and 10 have already
//  been sent since its last call to CheckForPipeMessages(), then an 11th message will fail.
//
//  The SendPipeMessage() takes an optional third parameter which tells it to keep retrying
//  for a given number of seconds if a message fails.
//
//  N.B. Requires "Allow DLL Imports" to be turned on
//
// *********************************************************************************************



// *********************************************************************************************
// DLL imports and associated constants used by the pipe client
// *********************************************************************************************

#define GENERIC_WRITE                  0x40000000
#define OPEN_EXISTING                  3
#define INVALID_HANDLE_VALUE           -1

#import "kernel32.dll"
   int CreateFileA(string Filename, int AccessMode, int ShareMode, int PassAsZero, int CreationMode, int FlagsAndAttributes, int AlsoPassAsZero);
   int CloseHandle(int fileHandle);
   int WriteFile(int FileHandle, string Buffer, int BufferLength, int & BytesWritten[], int PassAsZero);
#import


// *********************************************************************************************
// Private constants used by the client
// *********************************************************************************************

#define PIPE_BASE_NAME     "\\\\.\\pipe\\mt4-"     // MUST tally with server code


// *********************************************************************************************
// Simple function for sending a message (e.g. "Hello") to a server (e.g. "Test")
// *********************************************************************************************

// Sends a message to a server pipe, with optional retrying for a given number of seconds
bool SendPipeMessage(string ToPipe, string Message, int RetryForSeconds = 0)
{
   // Try an initial send
   if (SendPipeMessage2(ToPipe, Message)) {
      return (true);

   } else {
      // The initial send failed. Consider doing retries
      if (RetryForSeconds <= 0) {

         // Retries not allowed
         return (false);

      } else {
         // Keep retrying for n seconds
         int RetryUntilTime = TimeLocal() + RetryForSeconds;
         while (TimeLocal() < RetryUntilTime) {
            if (SendPipeMessage2(ToPipe, Message)) {
               return (true);
            } else {
               // Keep retrying - with a small pause between attempts
               Sleep(100);
            }
         }

         return (false);
      }
   }
}

// Function called by the above in order to do a single attempt to send a message
bool SendPipeMessage2(string ToPipe, string Message)
{
   bool bReturnvalue = false;

   string strPipeName = StringConcatenate(PIPE_BASE_NAME , ToPipe);

   // Try opening a connection to a free instance of the pipe
   int PipeHandle = CreateFileA(strPipeName, GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
   if (PipeHandle == INVALID_HANDLE_VALUE) {
      // We'd like to be able to inspect the last Win32 error in order to see
      // whether it's worth doing retries. However, we can't import the GetLastError()
      // function from the API, because it clashes with the internal MT4 name.
      // Therefore, we're a bit stuffed.
      bReturnvalue = false;

   } else {
      int BytesWritten[1] = {0};
      WriteFile(PipeHandle, Message, StringLen(Message), BytesWritten, 0);

      if (BytesWritten[0] > 0) {
         bReturnvalue = true;
      } else {
         bReturnvalue = false;
      }

      CloseHandle(PipeHandle);
   }

   return (bReturnvalue);
}

