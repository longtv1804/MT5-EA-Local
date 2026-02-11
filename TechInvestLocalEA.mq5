//+------------------------------------------------------------------+
//|                                            TechInvestLocalEA.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


/**********************************************************************
* handle order: close position, modify position, open position
*
***********************************************************************/
#include <Trade\Trade.mqh>

PositionInfo g_OpenPositions[];
PositionInfo g_OpositePositions[];

void AddPosition(PositionInfo arr[], PositionInfo &info)
{
   int size = ArraySize(arr);
   ArrayResize(arr, size + 1);
   arr[size] = info;
}

void RemovePositionByTicket(PositionInfo arr[], ulong position_ticket)
{
   int size = ArraySize(arr);
   for(int i = 0; i < size; i++)
   {
      if(arr[i].position_ticket == position_ticket)
      {
         for(int j = i; j < size - 1; j++)
         {
            arr[j] = arr[j + 1];
         }
         ArrayResize(arr, size - 1);
         break;
      }
   }
}

void UpdatePosition(PositionInfo arr[], PositionInfo &info)
{
   int size = ArraySize(arr);
   for(int i = 0; i < size; i++)
   {
      if(arr[i].position_ticket == info.position_ticket)
      {
         arr[i] = info;
         break;
      }
   }
}

void GetPositionsByTicket( PositionInfo info[], ulong position_ticket)
{
   int size = ArraySize(g_OpenPositions);
   for(int i = 0; i < size; i++)
   {
      if(g_OpenPositions[i].position_ticket == position_ticket)
      {
         info = g_OpenPositions[i];
         break;
      }
   }
}

//====================== MAIN EVENT =================================
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(!HistoryDealSelect(trans.deal))
         return;

      long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

      if(entry == DEAL_ENTRY_IN)
      {
         TradeInfo info;

         info.position_ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
         info.deal_ticket     = trans.deal;
         info.symbol          = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
         info.volume          = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
         info.price_open      = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
         info.time_open       = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
         info.status          = "OPEN";
         info.reason          = "OPEN";

         if(PositionSelectByTicket(info.position_ticket))
         {
            info.position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         }

         AddTrade(info);

         Print(">>> NEW POSITION OPENED: ", info.position_ticket);
      }

      if(entry == DEAL_ENTRY_OUT)
      {
         TradeInfo info;

         info.position_ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
         info.deal_ticket     = trans.deal;
         info.symbol          = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
         info.volume          = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
         info.price_close     = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
         info.time_close      = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
         info.status          = "CLOSED";

         info.reason = HistoryDealGetInteger(trans.deal, DEAL_REASON);

         AddTrade(info);

         Print(">>> POSITION CLOSED: ", info.position_ticket,
               " | Reason: ", info.reason);
      }
   }
}

/**********************************************************************
*
*   handle data communication with other MT5 terminal
*
***********************************************************************/
string FILE_INPUT = "bridge.txt";
string FILE_OUTPUT = "bridge_response.txt";

void Init()
{
   string server_name = AccountInfoString(ACCOUNT_SERVER);
   string server_lower = StringToLower(server_name);

   if(StringFind(server_lower, "exness") >= 0)
   {
      FILE_INPUT = "xm_data_exchange.txt";
      FILE_OUTPUT = "ex_data_exchange.txt";
   }
   else if(StringFind(server_lower, "xmglobal") >= 0)
   {
      FILE_INPUT = "ex_data_exchange.txt";
      FILE_OUTPUT = "xm_data_exchange.txt";
   }
   else
   {
      Print("Unknown broker: ", server_name);
   }
}

void SendData(string jsonData)
{
  int handle = FileOpen(FILE_OUTPUT, FILE_WRITE|FILE_TXT|FILE_COMMON);
  if(handle != INVALID_HANDLE)
  {
    FileWrite(handle, jsonData);
    FileClose(handle);
  }
}

string PollData()
{
  string result = "";
  int handle = FileOpen(FILE_INPUT, FILE_READ|FILE_TXT|FILE_COMMON);
  if(handle != INVALID_HANDLE)
  {
    result = FileReadString(handle);
    FileClose(handle);
  }
  return(result);
}

void OnCheck()
{
  string commandData = PollData();
  if(commandData != "")
  {
    // Process commandData as needed
  }
}

/**********************************************************************
*
*   EA main functions
*
***********************************************************************/

int OnInit()
{
  Init();
  EventSetTimer(1);
  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  EventKillTimer();

}

void OnTick()
{

}

void OnTimer()
{
  OnCheck();
}