#include "CPT_Strategy_Plan1.mqh"

/*
*    chỉ vào lệnh từ lệnh thứ i trở đi, các lệnh vào phải tương ứng với từng lệnh trước đó.
*/
class CPT_Strategy_AfterOrderX : public CPT_Strategy_DefaultPlan
{
    // lưu các server-position
    List<iPosition> mServerPositions;

    int mIdxStartOfStrategy;

public:
    CPT_Strategy_AfterOrderX(EnumStrategyPositionType type, double weight)
    : CPT_Strategy_DefaultPlan(type, weight),
        mServerPositions(new iPositionComparator())
    {
        mIdxStartOfStrategy = 0;
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
        // số lượng nhỏ hơn i: waiting
        if (mServerPositions.Size() < mIdxStartOfStrategy)
        {
            // do nothing
        }
        // đạt tới số lượng i: bắt đầu đặt lệnh
        else if (mServerPositions.Size() == mIdxStartOfStrategy)
        {
            for (int i = 0; i < mIdxStartOfStrategy; i++)
            {
                CPT_Strategy_DefaultPlan::OnServer_NewPositionAdded(*(mServerPositions.At(i)));
            }
        }
        // số Pos lớn hơn: add position như bình thường
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
            case EV_STATEGY_UPDATE_PARAMS:
                mIdxStartOfStrategy = ev.arg_int_1;
                break;
            default:
                CPT_Strategy_DefaultPlan::HandleEvent(ev);
                break;
        }
    }
};