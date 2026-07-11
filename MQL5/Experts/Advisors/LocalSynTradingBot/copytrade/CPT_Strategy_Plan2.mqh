#include "../lib/List.mqh"
#include "../lib/IComparator.mqh"
#include "../common/Types.mqh"
#include "../common/TradeUtils.mqh"
#include "../common/Utils.mqh"
#include "../common/TerminalApi.mqh"
#include "CPT_Strategy.mqh"

/*
*    vào lệnh giảm dần: 0.08 0.05 0.03 0.02 0.01 0.01
*/
class CPT_Stategy_DragDownVolume : public CPT_Strategy
{
private:
    enum
    {
        UPDATE_SL_DISTANCE = 7,
        SET_SL_DISTANCE = 5
    };
    EnumPositionType mType;
    double mVolumePlan[];
    int mPlanIdx;

    List<iPosition> mPositions;
    double mStopLostPrice;

    void SetStopLost(double value)
    {
        mStopLostPrice = value;
        LOGD("Strategy[" + PositionTypeToString(mType) + "] Set mStopLostPrice=" + (string)mStopLostPrice);
    }
    void UpdateStopLost(double value)
    {
        if (mType == ePOSITION_TYPE_BUY)
        {
            mStopLostPrice += MathAbs(value);
            LOGD("Strategy[" + PositionTypeToString(mType) + "] Update mStopLostPrice=" + (string)mStopLostPrice);
        }
        else if (mType == ePOSITION_TYPE_SELL)
        {
            mStopLostPrice -= MathAbs(value);
            LOGD("Strategy[" + PositionTypeToString(mType) + "] Update mStopLostPrice=" + (string)mStopLostPrice);
        }
        else
        {
            LOGE("Strategy[" + PositionTypeToString(mType) + "] error mType");
        }
    }

public:
    CPT_Stategy_DragDownVolume(EnumPositionType type)
    : mPositions(new iPositionComparator())
    {
        const double plan[] = {0.13, 0.08, 0.05, 0.03, 0.02, 0.01};
        ArrayCopy(mVolumePlan, plan);
        mStopLostPrice = 0;
        mPlanIdx = 0;
        mType = type;
    }

    double GetNextVolume(double serverVolume, double weight) override
    {
        int planSize = ArraySize(mVolumePlan);
        int planResIdx = mPlanIdx;
        if (mPlanIdx >= planSize)
        {
            planResIdx = planSize - 1;
        }
        else
        {
            planResIdx = mPlanIdx;
        }
        LOGD("Strategy[" + PositionTypeToString(mType) + "] planResIdx=" + (string)planResIdx + " planSize=" + (string)planSize);
        return mVolumePlan[planResIdx];
    }

    void OnPriceUpdate(double curPrice) override
    {
        if (mPlanIdx == 0 || mPositions.Size() == 0 || mStopLostPrice == 0.0)
            return;
        if (mType == ePOSITION_TYPE_BUY)
        {
            // check stoplost: nếu giá giảm/tăng tới mStopLostPrice thì close strategy
            if (curPrice <= mStopLostPrice || TradeUtils::IsSamePrice(curPrice , mStopLostPrice))
            {
                LOGD("Strategy[" + PositionTypeToString(mType) + "] STOPLOST detected: curPrice=" + (string)curPrice + " SL=" + (string)mStopLostPrice);
                for(int i = 0; i < mPositions.Size(); i++)
                {
                    const iPosition *pos = mPositions.At(i);
                    TerminalAPI::DoClosePosition(pos.position_ticket);
                }
            }
            // nâng SL dương: nếu giá tăng/giảm quá mốc SL x giá, nâng SL dương lên y giá.
            else
            {
                if (curPrice > mStopLostPrice && MathAbs(curPrice - mStopLostPrice) >= UPDATE_SL_DISTANCE)
                {
                    UpdateStopLost(UPDATE_SL_DISTANCE - SET_SL_DISTANCE);
                }
            }
        }
        else if (mType == ePOSITION_TYPE_SELL)
        {
            if (curPrice >= mStopLostPrice || TradeUtils::IsSamePrice(curPrice , mStopLostPrice))
            {
                LOGD("Strategy[" + PositionTypeToString(mType) + "] STOPLOST detected: curPrice=" + (string)curPrice + " SL=" + (string)mStopLostPrice);
                for(int i = 0; i < mPositions.Size(); i++)
                {
                    const iPosition *pos = mPositions.At(i);
                    TerminalAPI::DoClosePosition(pos.position_ticket);
                }
            }
            // nâng SL dương: nếu giá tăng/giảm quá mốc SL 10 giá, nâng SL dương 5 giá.
            else
            {
                if (curPrice < mStopLostPrice && MathAbs(curPrice - mStopLostPrice) >= UPDATE_SL_DISTANCE)
                {
                    UpdateStopLost(UPDATE_SL_DISTANCE - SET_SL_DISTANCE);
                }
            }
        }
        else
        {
            LOGE("Strategy[" + PositionTypeToString(mType) + "] Wrong mType");
        }
    }

    void OnNewPositionAdded(iPosition& newPos) override
    {
        mPositions.Add(newPos);
        mPlanIdx++;
        if (mPositions.Size() == 1)
        {
            double sl = newPos.price_open;
            if (mType == ePOSITION_TYPE_BUY)
            {
                sl -= SET_SL_DISTANCE;
            }
            else if (mType == ePOSITION_TYPE_SELL)
            {
                sl += SET_SL_DISTANCE;
            }
            else
            {
                LOGE("Strategy[" + PositionTypeToString(mType) + "] error mType");
            }
            SetStopLost(sl);
        }
        else
        {
            double zeroFpnlPrice = TradeUtils::BreakEvenPrice(mPositions);
            if (zeroFpnlPrice != 0)
            {
                SetStopLost(zeroFpnlPrice);
            }
            else
            {
                LOGE("Strategy[" + PositionTypeToString(mType) + "] zeroFpnlPrice = 0");
            }
        }
    }

    void OnPositionClose(iPosition& closedPos) override
    {
        mPositions.Remove(closedPos);
        if (mPositions.Size() == 0)
        {
            mPlanIdx = 0;
            SetStopLost(0);
        }
        else
        {
            double zeroFpnlPrice = TradeUtils::BreakEvenPrice(mPositions);
            if (zeroFpnlPrice != 0)
            {
                SetStopLost(zeroFpnlPrice);
            }
            else
            {
                LOGE("Strategy[" + PositionTypeToString(mType) + "] zeroFpnlPrice = 0");
            }
        }
    }
};