#include "../common/Types.mqh"

class CPT_Strategy
{
public:
    virtual double GetNextVolume(double serverVolume, double weight) = 0;
    virtual void OnPriceUpdate(double curPrice) = 0;
    virtual void OnNewPositionAdded(iPosition& newPos) = 0;
    virtual void OnPositionClose(iPosition& newPos) = 0;
};