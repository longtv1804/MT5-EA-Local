#include "CPT_Strategy_Plan1.mqh"

/*
*    chỉ vào lệnh từ lệnh thứ i trở đi, các lệnh vào phải tương ứng với từng lệnh trước đó.
*/
class CPT_Strategy_AfterOrderX : public CPT_Strategy_DefaultPlan
{
    // lưu các server-position
    List<iPosition> mServerPositions;

    int mIdxStartOfStrategy;
    bool mEnablePlaceOldPositions;
    bool mIsOrderTriggered;

    EnumTakeProfitMode mTakeProfitMode;
    double mTakeProfitDistance;
    double mStopLostDistance;

protected:
    virtual void On_OpendPositionDone(const Event &ev) override
    {
        EnumEventState closePosState = (EnumEventState)ev.arg_int_1;
        if (closePosState == EnumEventState::EVS_WAIITING_SUCCESS)
        {
            mSession.AddCopyTradePosition(ev.arg_ulong_1, ev.arg_ulong_2);

            // check closeing mode
            if (mTakeProfitMode == MODE_FOLLOW_TP_SL)
            {
                bool updateDone = false;
                do {
                    const iPosition pos = TerminalAPI::DoGetPosition(ev.arg_ulong_2);
                    if (pos.price_open == 0 || pos.position_type == ePOSITION_TYPE_UNKNOWN)
                    {
                        break;
                    }
                    double tp = pos.price_open;
                    double sl = pos.price_open;
                    if (pos.position_type == ePOSITION_TYPE_BUY)
                    {
                        tp += mTakeProfitDistance;
                        sl -= mStopLostDistance;
                    }
                    else    // ePOSITION_TYPE_SELL
                    {
                        tp -= mTakeProfitDistance;
                        sl += mStopLostDistance;
                    }
                    updateDone = TerminalAPI::PlaceTP(ev.arg_ulong_2, tp);
                    if (!updateDone) break;

                    updateDone = TerminalAPI::PlaceSL(ev.arg_ulong_2, sl);
                } while(false);
                
                if (!updateDone)
                {
                   STRATEGY_LOGD("place TP-SL failed -> do close position:" + (string)ev.arg_ulong_2);
                   TerminalAPI::DoClosePosition(ev.arg_ulong_2);
                }
            }
        }
        else
        {
            mSession.AddCopyTradePosition(ev.arg_ulong_1, 0);
        }
    }

public:
    CPT_Strategy_AfterOrderX(EnumStrategyPositionType type, double weight)
    : CPT_Strategy_DefaultPlan(type, weight),
        mServerPositions(new iPositionComparator())
    {
        mIdxStartOfStrategy = 0;
        mEnablePlaceOldPositions = false;
        mIsOrderTriggered = false;
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
        if (CheckServerPositionByType(newPos) == false)
            return;
        
        mServerPositions.Add(newPos);

        // chỉ vào lệnh sell hoặc buy, ko vào cả 2 cùng lúc
        if (mEnableBuySellInSameTime == false &&
            ((newPos.position_type == ePOSITION_TYPE_BUY && CommonDatacenter::s_SellPositionNum > 0) ||
             (newPos.position_type == ePOSITION_TYPE_SELL && CommonDatacenter::s_BuyPositionNum > 0)))
        {
           STRATEGY_LOGD("ignore, NOT allow buy/sell in the same time");
            return;
        }

        if (mIsOrderTriggered == false)
        {
            // số lượng nhỏ hơn i: waiting
            if (mServerPositions.Size() < mIdxStartOfStrategy)
            {
                // do nothing
            }
            // đạt tới số lượng i: bắt đầu đặt lệnh
            else
            {
                mIsOrderTriggered = true;
                if (mEnablePlaceOldPositions)
                {
                    int serverPosNum = mServerPositions.Size();
                    for (int i = 0; i < serverPosNum; i++)
                    {
                        CPT_Strategy_DefaultPlan::OnServer_NewPositionAdded(*(mServerPositions.At(i)));
                    }
                }
                else
                {
                    CPT_Strategy_DefaultPlan::OnServer_NewPositionAdded(newPos);
                }
            }
        }
        else
        {
             CPT_Strategy_DefaultPlan::OnServer_NewPositionAdded(newPos);
        }
    }

    void OnServer_PositionClosed(const iPosition &closedPos) override
    {
        // lọc bỏ các position ko liên quan tới strategy
        if (CheckServerPositionByType(closedPos) == false)
            return;
        
        mServerPositions.Remove(closedPos);
        if (mServerPositions.Size() == 0)
        {
            mIsOrderTriggered = false;
        }

        if (mTakeProfitMode == MODE_FOLLOW_TP_SL)
        {
            // do nothing: đóng lệnh dựa vào TP/SL
        }
        else // mode MODE_NORMAL
        {
            CPT_Strategy_DefaultPlan::OnServer_PositionClosed(closedPos);
        }
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
                SetDefaultStrategyParams(buffer);
                mIdxStartOfStrategy = buffer.ReadInt();
                mEnablePlaceOldPositions = buffer.ReadBool();
                mTakeProfitMode     =   (EnumTakeProfitMode)buffer.ReadInt();
                mTakeProfitDistance =   buffer.ReadDouble();
                mStopLostDistance   =   buffer.ReadDouble();
               STRATEGY_LOGD(   ""  + (string)mEnableBuySellInSameTime + " " + (string)mTakeProfitMode + 
                        " " + (string)mTakeProfitDistance + " " + (string)mStopLostDistance);
                STRATEGY_LOGD("EV_STRATEGY_UPDATE_PARAMS [" + (string)mIdxStartOfStrategy + ", " + (string)mEnablePlaceOldPositions + ", "
                                                            + (string)mTakeProfitMode + ", " + (string)mTakeProfitDistance + ", " + (string)mStopLostDistance + "]");
                break;
            }
            default:
                CPT_Strategy_DefaultPlan::HandleEvent(ev);
                break;
        }
    }
};