#include "CPT_Strategy_Plan1.mqh"

/*
*    SL ở lệnh thứ i
*/
class CPT_Strategy_UntillTheOrderX : public CPT_Strategy_DefaultPlan
{
private:
    // lưu các server-position
    List<iPosition> mServerPositions;

    int mStopLost_At_i;
    bool mStopLostTrigged;

protected:
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
    CPT_Strategy_UntillTheOrderX(EnumStrategyPositionType type, double weight)
    : CPT_Strategy_DefaultPlan(type, weight),
        mServerPositions(new iPositionComparator())
    {
        mStopLost_At_i = 0;
        mStopLostTrigged = false;
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

        ulong server_ticket = mSession.GetServerTicket(closedPos.position_ticket);
        CPT_Strategy_DefaultPlan::OnLocal_PositionClosed(closedPos);
        if (mStopLostTrigged == true && server_ticket != 0)
        {
            mSession.AddCopyTradePosition(server_ticket, 0);
        }
    }

    void OnServer_NewPositionAdded(const iPosition &newPos) override
    {
        // lọc bỏ các position ko liên quan tới strategy
        if (CheckServerPositionByType(newPos) == false)
            return;
        
        mServerPositions.Add(newPos);
        if (mStopLostTrigged)
        {
            mSession.AddCopyTradePosition(newPos.position_ticket, 0);
        }
        else
        {
            if (mServerPositions.Size() == mStopLost_At_i)
            {
                STRATEGY_LOGD("server-pos=" + (string)mServerPositions.Size() + " close all positions");
                Event ev = ObtainEvent(EV_STRATEGY_CLOSE_ALL_POSITIONS_WITHOUT_SERVER_TRIGGER);
                SendEvent(ev);
                mStopLostTrigged = true;
            }
            else if (mServerPositions.Size() > mStopLost_At_i)
            {
                STRATEGY_LOGE("not expected, mStopLostTrigged=false");
            }
            else
            {
                // vào lệnh như bình thường
                CPT_Strategy_DefaultPlan::OnServer_NewPositionAdded(newPos);
            }
        }
    }

    void OnServer_PositionClosed(const iPosition &closedPos) override
    {
        // lọc bỏ các position ko liên quan tới strategy
        if (CheckServerPositionByType(closedPos) == false)
            return;
        
        mServerPositions.Remove(closedPos);
        // khi mServerPositions về 0 -> chuyển flag về false để vào lượt lệnh mới
        if (mServerPositions.Size() == 0)
        {
            mStopLostTrigged = false;
        }
        CPT_Strategy_DefaultPlan::OnServer_PositionClosed(closedPos);
    }

    virtual void HandleEvent(const Event &ev) override
    {
        if(ev.state != EnumEventState::EVS_DISPATCHING)
        {
            STRATEGY_LOGE("Event is in wrong state " + (string)ev.eventId + " " + (string)ev.state);
            return;
        }
        STRATEGY_LOGD("EventId=" + EventToString(ev.eventId));
        switch (ev.eventId)
        {
            case EV_STRATEGY_UPDATE_PARAMS:
            {
                ByteBuffer buffer(ev.data);
                                    buffer.ReadInt();       // ignore first number
                mStopLost_At_i =    buffer.ReadInt();
                if (mStopLost_At_i <= 1)
                {
                    STRATEGY_LOGD("User set wrong mStopLost_At_i, make it to default");
                    mStopLost_At_i = 2;
                }
                STRATEGY_LOGD("mStopLost_At_i=" + (string)mStopLost_At_i);
                break;
            }
            case EV_STRATEGY_CLOSE_ALL_POSITIONS_WITHOUT_SERVER_TRIGGER:
                Do_CloseAllPositionsWithoutServerTrigger();
                break;
            default:
                CPT_Strategy_DefaultPlan::HandleEvent(ev);
                break;
        }
    }
};