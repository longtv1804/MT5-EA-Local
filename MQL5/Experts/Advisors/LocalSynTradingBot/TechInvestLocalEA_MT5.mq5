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
input group "----- Socket Setting -----"
input ushort i_SocketPort = 25000;                  // Cổng socket local (127.0.0.1)
input int i_PollIntervalMs = 50;                    // Chu kỳ OnTimer poll socket (ms)
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
        isInitOk = g_CopyTradeController.Init(i_TerminalMode, i_Weight, i_SocketPort);
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
        ByteBuffer buffer;
        buffer.WriteInt(i_Plan3_StartAtIdx);
        buffer.WriteBool(i_Plan3_PlaceOldPositions);
        buffer.WriteInt(i_Plan4_StopLostAtIdx);
        g_CopyTradeController.SetStrategyParam(buffer);

        // timer tính bằng mili-giây:
        //   client chỉ đọc socket trong OnTimer -> nếu để 1s thì bản tin
        //   copy bị trễ tới 1s. Đặt 50ms (tối thiểu 10ms).
        int pollInterval = i_PollIntervalMs;
        if (pollInterval < 10)
        {
            pollInterval = 10;
        }
        if (pollInterval > 5000)
        {
            pollInterval = 5000;
        }
        EventSetMillisecondTimer((uint)pollInterval);

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