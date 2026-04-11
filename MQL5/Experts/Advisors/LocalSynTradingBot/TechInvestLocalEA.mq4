//+------------------------------------------------------------------+
//|                                            TechInvestLocalEA.mq4 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "AutoTpController.mqh"
#include "TpSlController.mqh"

// ================= INPUT =================
extern bool i_FEATURE_AUTO_PLACE_REMOVE_TP = true;     // tool của sangtv
extern bool i_FEATURE_AUTO_TP = true;     // tool auto TP khi mà SL.

extern double iEquity_Og = 1000.0;      // Original equity
extern double iPercent_SetTP = 70.0;    // % equity set TP
extern double iPercent_ClearTP = -30.0; // % equity clear TP
extern double iVal_TP = 0.0;            // TP (Only SELL)

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
int init()
{
   Print("*************** EA INIT ****************");

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
   return(0);
}

int deinit()
{
   EventKillTimer();
   g_AutoTpController.Terminate();
   Print("*************** EA FINISH ***************");
   return(0);
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

// Lưu ý: MQL4 không có OnTradeTransaction, cần chuyển logic này sang OnTrade hoặc xử lý khác phù hợp.
