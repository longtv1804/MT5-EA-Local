#include "../common/Types.mqh"
#include "../queue/Handler.mqh"

class CPT_Strategy : public Handler
{
public:
    virtual double GetNextVolume(double serverVolume, double weight) = 0;
    virtual void OnPriceUpdate(double curPrice) = 0;
    virtual void OnNewPositionAdded(const iPosition& newPos) = 0;
    virtual void OnPositionClose(const iPosition& newPos) = 0;
};