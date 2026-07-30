//+------------------------------------------------------------------+
//|                                        TechInvestLocalEA_MT5.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "copytrade/CopyTradeController.mqh"
#include "common/Types.mqh"
#include "common/Utils.mqh"
#include "common/Constants.mqh"
#include "PositionMonitor.mqh"
#include "lib/ByteBuffer.mqh"

// ================= INPUT =================
input group "---- Common Setting ----"
input EnumCopyTradeMode i_TerminalMode = 0;         // Copy Mode
input double i_Weight = 1.0;                        // trọng số
input group "----- Plan Setting -----"
input EnumStrategyPlanId i_CopyTradePlan = 1;       // plan_id
input int i_Plan3_StartAtIdx = 0;                   // PLAN3: vào lệnh từ Position số
input bool i_Plan3_PlaceOldPositions = true;        // PLAN3: vào cả các lệnh chưa vào
input int i_Plan4_StopLostAtIdx = 0;                // PLAN4: StopLost ở lệnh số
// input double i_StopLossThreshold = 100.00;          // Giới hạn âm(SL)
// input double i_TakeProfitThreshold = 200.00;        // Giới hạn TakeProfit

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
   PositionMonitor::GetInstance().CheckLocalPositionChanged();
}

int OnInit()
{
    LOGD("*************** LOCAL EA COPY TRADING INIT (" + CPT_EA_VER + ")****************");

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
        ByteBuffer params;
        if (i_CopyTradePlan == PLAN_ID_1)
        {
            // no param
        }
        else if (i_CopyTradePlan == PLAN_ID_2)
        {
            // no param
        }
        else if (i_CopyTradePlan == PLAN_ID_3)
        {
            params.WriteInt(i_Plan3_StartAtIdx);
            params.WriteBool(i_Plan3_PlaceOldPositions);
        }
        else if (i_CopyTradePlan == PLAN_ID_4)
        {
            params.WriteInt(i_Plan4_StopLostAtIdx);
        }
        else if (i_CopyTradePlan == PLAN_ID_5)
        {
            // no param
        }
        else
        {
            // no param
        }
        g_CopyTradeController.SetStrategyParam(params);

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
    g_CopyTradeController.Terminate();
    EventKillTimer();
    LOGD("*************** EA FINISH ***************");
}

void OnTimer()
{
    g_CopyTradeController.OnTimer();
}