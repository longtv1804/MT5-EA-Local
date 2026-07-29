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
        if (mIsOrderTriggered == false)
        {
            // số lượng nhỏ hơn i: waiting
            if (mServerPositions.Size() < mIdxStartOfStrategy)
            {
                // do nothing
            }
            // đạt tới số lượng i: bắt đầu đặt lệnh
            else if (mServerPositions.Size() == mIdxStartOfStrategy)
            {
                mIsOrderTriggered = true;
                if (mEnablePlaceOldPositions)
                {
                    for (int i = 0; i < mIdxStartOfStrategy; i++)
                    {
                        CPT_Strategy_DefaultPlan::OnServer_NewPositionAdded(*(mServerPositions.At(i)));
                    }
                }
                else
                {
                    CPT_Strategy_DefaultPlan::OnServer_NewPositionAdded(newPos);
                }
            }
            // số Pos lớn hơn: add position như bình thường
            else
            {
                CPT_Strategy_DefaultPlan::OnServer_NewPositionAdded(newPos);
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
        CPT_Strategy_DefaultPlan::OnServer_PositionClosed(closedPos);
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
                mIdxStartOfStrategy = buffer.ReadInt();
                mEnablePlaceOldPositions = buffer.ReadBool();
                STRATEGY_LOGD("EV_STRATEGY_UPDATE_PARAMS mIdxStartOfStrategy=" + (string)mIdxStartOfStrategy + " mEnablePlaceOldPositions=" + (string)mEnablePlaceOldPositions);
                break;
            }
            default:
                CPT_Strategy_DefaultPlan::HandleEvent(ev);
                break;
        }
    }
};