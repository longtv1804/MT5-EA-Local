#include "CPT_Strategy.mqh"
#include "../common/TradeUtils.mqh"
/*
*    vào lệnh giảm tăng dần theo volume của serverVolume
*/
class CPT_Stategy_UnlimitedVolume : public CPT_Strategy
{
public:
    double GetNextVolume(double serverVolume, double weight) override 
    {
        LOGD("GetNextVolume");
        return TradeUtils::NormalizeVolume(_Symbol, serverVolume * weight);
    }
    
    void OnPriceUpdate(double curPrice) override 
    {}

    void OnNewPositionAdded(iPosition& newPos) override
    {}

    void OnPositionClose(iPosition& newPos) override 
    {}
};