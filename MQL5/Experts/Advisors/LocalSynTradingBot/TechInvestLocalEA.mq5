//+------------------------------------------------------------------+
//|                                            TechInvestLocalEA.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "AutoTpController.mqh"
#include "TpSlController.mqh"
#include "Utils.mqh"

// ================= INPUT =================
input bool i_FEATURE_AUTO_PLACE_REMOVE_TP = true;     // tool của sangtv
input bool i_FEATURE_AUTO_TP = true;     // tool auto TP khi mà SL.

input double iEquity_Og = 1000.0;      // Original equity
input double iPercent_SetTP = 70.0;    // % equity set TP
input double iPercent_ClearTP = -30.0; // % equity clear TP
input double iVal_TP = 0.0;            // TP (Only SELL)

/**********************************************************************
*
*   golbal variable
*
***********************************************************************/
AutoTpController g_AutoTpController;
TpSLController g_TpSlController;

/**********************************************************************
*
*   EA main functions
*
***********************************************************************/
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if (i_FEATURE_AUTO_TP)
   {
        g_AutoTpController.OnLocal_OnTradeTransaction(trans, request, result);
   }
}

int OnInit()
{
    LOGD("*************** EA INIT ****************");

    if (i_FEATURE_AUTO_TP)
    {
            g_AutoTpController.Init();
    }
    if (i_FEATURE_AUTO_PLACE_REMOVE_TP 
            && CommonDatacenter::sLOCAL_TERMINAL_TYPE == eTERMINAL_TYPE_XM)
    {
        g_TpSlController.Init(iEquity_Og, iPercent_SetTP, iPercent_ClearTP, iVal_TP);
    }
    EventSetTimer(1);
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    EventKillTimer();
    g_AutoTpController.Terminate();
    LOGD("*************** EA FINISH ***************");
}

void OnTimer()
{
    if (i_FEATURE_AUTO_PLACE_REMOVE_TP 
        && CommonDatacenter::sLOCAL_TERMINAL_TYPE == eTERMINAL_TYPE_XM)
    {
        g_TpSlController.OnTick();
    }
    if (i_FEATURE_AUTO_TP)
    {
        g_AutoTpController.OnTimer();
    }
}