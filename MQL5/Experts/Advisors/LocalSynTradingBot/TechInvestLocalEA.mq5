//+------------------------------------------------------------------+
//|                                            TechInvestLocalEA.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "LocalTerminal.mqh"
#include "RemoteTerminal.mqh"

/**********************************************************************
*
*   golbal variable
*
***********************************************************************/
LocalTerminal g_MyTerminal;
RemoteTerminal g_RemoteTerminal(&g_MyTerminal);

/**********************************************************************
*
*   EA main functions
*
***********************************************************************/
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   g_MyTerminal.OnLocal_OnTradeTransaction(trans, request, result);
}

int OnInit()
{
   LOGD("*************** EA INIT ****************");
   g_MyTerminal.init();
   g_RemoteTerminal.init();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   LOGD("*************** EA FINISH ***************");
}

// void OnTick()
// {

// }

void OnTimer()
{
   g_RemoteTerminal.DoPoll();
}