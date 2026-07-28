#include "../common/Logging.mqh"
#include "../common/Types.mqh"
#include "CPT_Strategy.mqh"
#include "CPT_Strategy_Plan1.mqh"
//#include "CPT_Strategy_Plan2.mqh"
#include "CPT_Strategy_Plan3.mqh"
#include "CPT_Strategy_Plan4.mqh"
//#include "CPT_Strategy_Plan5.mqh"

class CPT_Strategy_Factory
{
public:
    static CPT_Strategy* Make(EnumStrategyPlanId planId, EnumStrategyPositionType type, double weight)
    {
        switch(planId)
        {
            case PLAN_ID_1: return new CPT_Strategy_DefaultPlan(type, weight);
            //case PLAN_ID_2: return new CPT_Strategy_DragDownVolume(type, weight);
            case PLAN_ID_3: return new CPT_Strategy_AfterOrderX(type, weight);
            case PLAN_ID_4: return new CPT_Strategy_UntillTheOrderX(type, weight);
            //case PLAN_ID_5: return new CPT_Strategy_RevertCopy(type, weight);
            default:
                return NULL;
        }
    }
};