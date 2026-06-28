//+------------------------------------------------------------------+
//|                                        TechInvestLocalEA_MT5.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "copytrade/CopyTradeController.mqh"
#include "common/Utils.mqh"

// ================= INPUT =================
input int i_TerminalMode = 0;       // mode: 1 server, 2, 3, 4, 5.. clients
input double i_Weight = 1.0;        // trong so
input bool i_RevertPositionEnable = false;      // vao lenh nguoc
input double i_RpStopLossThreshold = 100.00;    // gioi han am
input double i_RpTakeProfitThreshold = 200.00;  // gioi han de takeprofit

/**********************************************************************
*
*   golbal variable
*
***********************************************************************/
CopyTradeController g_CopyTradeController;

/**********************************************************************
*
*   EA main functions
*
***********************************************************************/
void OnTrade()
{
   g_CopyTradeController.CheckLocalPositionChanged();
}

int OnInit()
{
    LOGD("*************** LOCAL EA COPY TRADING INIT ****************");

    if (i_TerminalMode == eCPT_MODE_UNKNOWN)
    {
        TerminalAPI::DoShowMessagePopup("You haven't set the CopyTrade mode!!");
        return(INIT_FAILED);
    }

    TerminalAPI::DetectBroker();
    if (CommonDatacenter::sLOCAL_TERMINAL_TYPE  == eTERMINAL_TYPE_UNKNOWN)
    {
        LOGE("can not detect the brocker");
    }

    bool isOk = g_CopyTradeController.Init(i_TerminalMode, i_Weight);
    if (!isOk)
    {
        return INIT_FAILED;
    }
    g_CopyTradeController.SetRevertPositionParam(i_RevertPositionEnable, i_RpStopLossThreshold, i_RpTakeProfitThreshold);
    EventSetTimer(1);
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    g_CopyTradeController.Terminate();
    EventKillTimer();
    LOGD("*************** EA FINISH ***************");
}

void OnTimer()
{
    g_CopyTradeController.OnTimer();
}