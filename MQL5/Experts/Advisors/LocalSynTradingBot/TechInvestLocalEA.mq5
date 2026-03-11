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
#include "TpSlController.mqh"

// ================= INPUT =================
input double iEquity_Og = 1000.0;      // Original equity
input double iPercent_SetTP = 70.0;    // % equity set TP
input double iPercent_ClearTP = -30.0; // % equity clear TP
input double iVal_TP = 0.0;            // TP (Only SELL)

/**********************************************************************
*
*   golbal variable
*
***********************************************************************/
LocalTerminal g_MyTerminal;
RemoteTerminal g_RemoteTerminal(&g_MyTerminal);
//TpSLController g_TpSlController;

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
   LOGD("");
   LOGD("*************** EA INIT ****************");
   g_MyTerminal.init();
   //g_RemoteTerminal.init();
   g_TpSlController.Init(iEquity_Og, iPercent_SetTP, iPercent_ClearTP, iVal_TP);
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   g_MyTerminal.termniate();
   LOGD("*************** EA FINISH ***************");
}

// void OnTick()
// {

// }

void OnTimer()
{
   g_RemoteTerminal.DoPoll();
   g_TpSlController.OnTick();
}
