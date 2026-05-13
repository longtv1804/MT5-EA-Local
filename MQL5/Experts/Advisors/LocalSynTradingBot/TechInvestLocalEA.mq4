//+------------------------------------------------------------------+
//|                                            TechInvestLocalEA.mq5 |
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
        LOGE("can not detect the brocker");
        return(INIT_FAILED);
    }

    TerminalAPI::DetectBroker();
    if (CommonDatacenter::sLOCAL_TERMINAL_TYPE  == eTERMINAL_TYPE_UNKNOWN)
    {
        TerminalAPI::DoShowMessagePopup("can not detect the brocker!!!");
        LOGE("can not detect the brocker");
        return(INIT_FAILED);
    }

    bool isOk = g_CopyTradeController.Init(i_TerminalMode, i_Weight);
    if (!isOk)
    {
        return INIT_FAILED;
    }
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