//+------------------------------------------------------------------+
//|                                        TechInvestLocalEA_MT4.mq4 |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2000-2026, MetaQuotes Ltd."
#property link        "https://www.mql5.com"

#include "copytrade/CopyTradeController.mqh"
#include "common/Utils.mqh"
#include "common/Constants.mqh"
#include "PositionMonitor.mqh"

// ================= INPUT =================
input int i_TerminalMode = 0;       // mode: 1 server, 2, 3, 4, 5.. clients
input double i_Weight = 1.0;        // trong so
input int i_CopyTradePlan = 1;             // plan_id
input double i_StopLossThreshold = 100.00;    // gioi han am
input double i_TakeProfitThreshold = 200.00;  // gioi han de takeprofit

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
    LOGD("*************** LOCAL EA COPY TRADING INIT (" + CPT_EA_VER + ")****************");

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

    PositionMonitor::GetInstance().InitFirstSnapshot();

    bool isInitOk = false;
    do {
        // init connection and client/server first
        isInitOk = g_CopyTradeController.Init(i_TerminalMode, i_Weight);
        if (!isInitOk)
        {
            break;
        }

        // init strategy
        isInitOk = g_CopyTradeController.SetStrategyPlan(i_CopyTradePlan);
        if (!isInitOk)
        {
            break;
        }

        // set các param khác
        g_CopyTradeController.SetStrategyParam(i_StopLossThreshold, i_TakeProfitThreshold);

        // finally: init the timer
        EventSetTimer(1);

    } while(false);

    if (!isInitOk)
    {
        LOGD("Init EA FAILED!!!");
        return INIT_FAILED;
    }
    else
    {
        LOGD("Init EA SUCCESSED!!!");
        return INIT_SUCCEEDED;
    }
}

void OnDeinit(const int reason)
{
    EventKillTimer();
    g_CopyTradeController.Terminate();
    LOGD("*************** EA FINISH ***************");
}

void OnTimer()
{
    PositionMonitor::GetInstance().CheckLocalPositionChanged();
    g_CopyTradeController.OnTimer();
}