//+------------------------------------------------------------------+
//|                                        TechInvestLocalEA_MT4.mq4 |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2000-2026, MetaQuotes Ltd."
#property link        "https://www.mql5.com"

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
int OnInit()
{
    LOGD("*************** LOCAL EA COPY TRADING INIT ****************");

    if (i_TerminalMode == eCPT_MODE_UNKNOWN)
    {
        TerminalAPI::DoShowMessagePopup("You haven't set the CopyTrade mode!!");
        LOGE("You haven't set the CopyTrade mode!!");
        TerminalAPI::DoCloseEA();
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
        TerminalAPI::DoCloseEA();
        return INIT_FAILED;
    }
    g_CopyTradeController.SetRevertPositionParam(i_RevertPositionEnable, i_RpStopLossThreshold, i_RpTakeProfitThreshold);
    EventSetTimer(1);
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    EventKillTimer();
    g_CopyTradeController.Terminate();
    LOGD("*************** EA FINISH ***************");
}

void OnTimer()
{
    g_CopyTradeController.OnTimer();
}