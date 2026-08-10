//+------------------------------------------------------------------+
//|                                        TechInvestLocalEA_MT4.mq4 |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2000-2026, MetaQuotes Ltd."
#property link        "https://www.mql5.com"

#include "copytrade/CopyTradeController.mqh"
#include "common/Types.mqh"
#include "common/Utils.mqh"
#include "common/Constants.mqh"
#include "PositionMonitor.mqh"
#include "lib/ByteBuffer.mqh"

// ================= INPUT =================
input const string COMMON_setting = "---- Common Setting ----";
input EnumCopyTradeMode i_TerminalMode = 0;         // Copy Mode
input double i_Weight = 1.0;                        // trong so
input double i_TotalSL = 0;                         // % SL/Equity
input bool i_BuySellInSametime = true;              // Buy-Sell Cùng lúc

input const string PLAN_setting = "---- Setting for Plan ----";
input EnumStrategyPlanId i_CopyTradePlan = 1;       // plan_id

input int i_Plan3_StartAtIdx = 0;                       // PLAN3: vao lenh tu Position so
input bool i_Plan3_PlaceOldPositions = true;            // PLAN3: vao cac lenh chua vao
input EnumTakeProfitMode i_Plan3_TakeProfitMode = 0;    // PLAN3: Take profit mode
input double i_Plan3_TP_Distance = 0;                   // PLAN3: Take profit price distance
input double i_Plan3_Sl_Distance = 0;                   // PLAN3: Stop Lost price distance

input int i_Plan4_StopLostAtIdx = 0;                // PLAN4: StopLost o lenh so
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

        // Set Total Stoplost
        g_CopyTradeController.SetTotalStopLost(i_TotalSL);

        // set các param khác
        ByteBuffer params;
        params.WriteBool(i_BuySellInSametime);
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
            if (i_Plan3_TakeProfitMode != 0 && (i_Plan3_TP_Distance == 0 || i_Plan3_Sl_Distance == 0))
            {
                isInitOk = false;
                LOGD("mode AUTO TP-SL but TP=" + (string)i_Plan3_TP_Distance + " SL=" +(string)i_Plan3_Sl_Distance);
                break;
            }
            params.WriteInt(i_Plan3_StartAtIdx);
            params.WriteBool(i_Plan3_PlaceOldPositions);
            params.WriteInt(i_Plan3_TakeProfitMode);
            params.WriteDouble(i_Plan3_TP_Distance);
            params.WriteDouble(i_Plan3_Sl_Distance);
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
    EventKillTimer();
    g_CopyTradeController.Terminate();
    LOGD("*************** EA FINISH ***************");
}

void OnTimer()
{
    PositionMonitor::GetInstance().CheckLocalPositionChanged();
    g_CopyTradeController.OnTimer();
}