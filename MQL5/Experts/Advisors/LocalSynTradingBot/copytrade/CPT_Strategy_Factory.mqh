#include "../common/Types.mqh"
#include "CPT_Strategy.mqh"
#include "CPT_Strategy_Plan1.mqh"
#include "CPT_Strategy_Plan2.mqh"

class CPT_Strategy_Factory
{
public:
	enum {
		TYPE_PLAN_1 = 1,	// vào lệnh tăng dần theo server
		TYPE_PLAN_2 = 2,	// vào lệnh volume giảm dần
		TYPE_PLAN_3 = 3,	// vào lệnh volume giảm dần, kèm vào lệnh 2 chiều ở lệnh đầu tiên
	};

	static CPT_Strategy* MakeStrategy(int type, EnumPositionType strategyType)
	{
		switch(type)
		{
			case TYPE_PLAN_1: return new CPT_Stategy_UnlimitedVolume();
			case TYPE_PLAN_2: return new CPT_Stategy_DragDownVolume(strategyType);
			default:
				return NULL;
		}
	}
};