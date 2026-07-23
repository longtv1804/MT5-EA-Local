#include "../common/Logging.mqh"
#include "../common/Types.mqh"
#include "CPT_Strategy.mqh"
#include "CPT_Strategy_Plan1.mqh"
//#include "CPT_Strategy_Plan2.mqh"

enum EnumStrategyPlanId {
    PLAN_ID_1 = 1,    // vào lệnh tăng dần theo server
    PLAN_ID_2 = 2,    // vào lệnh volume giảm dần
    PLAN_ID_3 = 3,    // vào lệnh volume giảm dần, kèm vào lệnh 2 chiều ở lệnh đầu tiên
    PLAN_ID_MAX
};

class CPT_Strategy_Factory
{
public:
    static CPT_Strategy* Make(EnumStrategyPlanId planId, EnumStrategyPositionType type, double weight)
    {
        switch(planId)
        {
            case PLAN_ID_1: return new CPT_Stategy_DefaultPlan(type, weight);
            //case PLAN_ID_2: return new CPT_Stategy_DragDownVolume(type, weight);
            default:
                return NULL;
        }
    }
};