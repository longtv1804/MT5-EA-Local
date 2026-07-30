#include "../lib/List.mqh"
#include "../lib/IComparator.mqh"
#include "../common/Types.mqh"
#include "../common/TradeUtils.mqh"
#include "../common/Utils.mqh"
#include "../common/Logging.mqh"
#include "../common/TerminalApi.mqh"
#include "CPT_Strategy_Plan1.mqh"

/*
*    vào lệnh giảm dần: 0.13 0.08 0.05 0.03 0.02 0.01 0.01
*/
class CPT_Strategy_RevertCopy : public CPT_Strategy_DefaultPlan
{
private:
    double mTakeProfitValue;
    double mTakeProfitPrice;

    List<iPosition> mServerPosition;
    List<iPosition> mLocalPosition;
    bool mIsTakeProfitTriggered;

    void RecalculateTakeProfitPrice()
    {
        double averagePrice = TradeUtils::AverageOpenPrice(mLocalPosition);
        double buyVolume = TradeUtils::TotalVolume(ePOSITION_TYPE_BUY, mLocalPosition);
        double sellVolume = TradeUtils::TotalVolume(ePOSITION_TYPE_SELL, mLocalPosition);
        double distanceToTP = 0;
        if (buyVolume == sellVolume)
        {

        }
        else if (buyVolume > sellVolume)
        {

        }
        else
        {
            distanceToTP = 0;
        }

        double distanceToTP = mTakeProfitValue / 100 / volume;
        if (mStrategyPositionType == eSPT_BUY)
        {
            mTakeProfitPrice = averagePrice + distanceToTP;
        }
        else if (mStrategyPositionType == eSPT_SELL)
        {
            mTakeProfitPrice = averagePrice - distanceToTP;
        }
        else
        {
            LOGE();
        }
    }

    virtual void Do_CloseAllPositionsWithoutServerTrigger()
    {
        ulong tradingData[];
        int size = mSession.GetTradingData(tradingData);
        for (int i = 0; i < size; i += 2)
        {
            if (tradingData[i + 1] != 0)
            {
                TerminalAPI::DoClosePosition(tradingData[i + 1]);
            }
        }
    }

public:
    CPT_Strategy_RevertCopy(EnumStrategyPositionType type, double weight)
    : CPT_Strategy_DefaultPlan(type, weight)
    {
        mTakeProfitValue = 0.0;
        mIsTakeProfitTriggered = false;
    }

    void OnPriceUpdate(double curPrice)
    {
        
    }

    void OnLocal_PositionAdded(const iPosition& newPos) override
    {
        // lọc bỏ các position ko liên quan tới strategy
        if (CheckPositionByType(newPos) == false)
            return;

        CPT_Strategy_DefaultPlan::OnLocal_PositionAdded(newPos);
    }

    void OnLocal_PositionClosed(const iPosition& closedPos) override
    {
        // lọc bỏ các position ko liên quan tới strategy
        if (CheckPositionByType(closedPos) == false)
            return;

        CPT_Strategy_DefaultPlan::OnLocal_PositionClosed(closedPos);
    }

    void OnServer_NewPositionAdded(const iPosition &newPos) override
    {
        // lọc bỏ các position ko liên quan tới strategy
        if (RP_CheckServerPositionByType(newPos) == false)
            return;

        if (mSession.HasServerTicket(newPos.position_ticket))
        {
            STRATEGY_LOGE("server-ticket is already in the trading map: " + (string)newPos.position_ticket);
            return;
        }
        CopyTradeReqData reqData = {0};
        reqData.server_ticket = newPos.position_ticket;
        if (newPos.position_type == ePOSITION_TYPE_BUY)
        {
            reqData.position_type = ePOSITION_TYPE_SELL;
        }
        else if (newPos.position_type == ePOSITION_TYPE_SELL)
        {
            reqData.position_type = ePOSITION_TYPE_BUY;
        }
        else
        {
            STRATEGY_LOGE("Wrong position type");
        }
        reqData.volume = TradeUtils::NormalizeVolume(_Symbol, newPos.volume * mSession.GetWeight());
        Event ev = ObtainEvent(EV_ADD_NEW_POSITION);
        EventUtils::ToData(ev, reqData);
        SendEvent(ev);
    }

    void OnServer_PositionClosed(const iPosition &closedPos) override
    {
        // lọc bỏ các position ko liên quan tới strategy
        if (RP_CheckServerPositionByType(closedPos) == false)
            return;

        CPT_Strategy_DefaultPlan::OnServer_PositionClosed(closedPos);
    }

    virtual void OnServerUpdate(const iPosition &server_positions[], const iPosition &now_client_positions[]) override
    {
        int i = 0;

        int size = ArraySize(server_positions);
        iPosition strategy_serverPosArr[];
        int strategy_serverPosArr_size = 0;
        for (i = 0; i < size; i++)
        {
            if (RP_CheckServerPositionByType(server_positions[i]))
            {
                ArrayResize(strategy_serverPosArr, strategy_serverPosArr_size + 1);
                strategy_serverPosArr[strategy_serverPosArr_size] = server_positions[i];
                strategy_serverPosArr_size++;
            }
        }

        size = ArraySize(now_client_positions);
        iPosition strategy_localPosArr[];
        int strategy_localPosArr_size = 0;
        for (i = 0; i < size; i++)
        {
            if (CheckPositionByType(now_client_positions[i]))
            {
                ArrayResize(strategy_localPosArr, strategy_localPosArr_size + 1);
                strategy_localPosArr[strategy_localPosArr_size] = now_client_positions[i];
                strategy_localPosArr_size++;
            }
        }

        CPT_Strategy_DefaultPlan::OnServerUpdate(strategy_serverPosArr, strategy_localPosArr);
    }

    virtual void HandleEvent(const Event &ev) override
    {
        if(ev.state != EnumEventState::EVS_DISPATCHING)
        {
            STRATEGY_LOGE("Event is in wrong state " + (string)ev.eventId + " " + (string)ev.state);
            return;
        }
        switch (ev.eventId)
        {
            case EV_STRATEGY_UPDATE_PARAMS:
            {
                ByteBuffer buffer(ev.data);
                mTakeProfitValue =  buffer.ReadDouble();
                STRATEGY_LOGD("EV_STRATEGY_UPDATE_PARAMS mTakeProfitValue=" + (string)mTakeProfitValue);
                break;
            }
            case EV_STRATEGY_CLOSE_ALL_POSITIONS_WITHOUT_SERVER_TRIGGER:
                STRATEGY_LOGD("EV_STRATEGY_CLOSE_ALL_POSITIONS_WITHOUT_SERVER_TRIGGER");
                Do_CloseAllPositionsWithoutServerTrigger();
                break;
            default:
                CPT_Strategy_DefaultPlan::HandleEvent(ev);
                break;
        }
    }
};