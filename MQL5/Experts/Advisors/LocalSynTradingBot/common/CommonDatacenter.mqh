#include "Types.mqh"
#include "Logging.mqh"

class CommonDatacenter
{
private:
	CommonDatacenter() {}
	~CommonDatacenter() {}

public:
	static EnumTerminalType sLOCAL_TERMINAL_TYPE;
	static string sFILE_OUTPUT;
	static string sFILE_INPUT;

    static EnumCopyTradeMode s_copyTradeMode;

	static double s_TodayStartEquity;
	static uint s_BuyPositionNum;
	static uint s_SellPositionNum;

	static void OnPositionChanged(const iPosition& pos)
	{
		if (pos.position_type != ePOSITION_TYPE_BUY && pos.position_type != ePOSITION_TYPE_SELL)
		{
			LOGE("Wrong position type.");
			return;
		}
		if (pos.status != ePOSITION_STATUS_OPEN && pos.status != ePOSITION_STATUS_CLOSED)
		{
			LOGE("Wrong status.");
			return;
		}

		if (pos.status == ePOSITION_STATUS_OPEN)
		{
			if (pos.position_type == ePOSITION_TYPE_BUY)
			{
				s_BuyPositionNum++;
			}
			else //if (pos.position_type == ePOSITION_TYPE_SELL)
			{
				s_SellPositionNum++;
			}
		}
		else //if (pos.status == ePOSITION_STATUS_CLOSED)
		{
			if (pos.position_type == ePOSITION_TYPE_BUY)
			{
				s_BuyPositionNum--;
			}
			else //if (pos.position_type == ePOSITION_TYPE_SELL)
			{
				s_SellPositionNum--;
			}
		}
	}
};

// Định nghĩa các biến static bên ngoài class
EnumTerminalType CommonDatacenter::sLOCAL_TERMINAL_TYPE = eTERMINAL_TYPE_UNKNOWN;
string CommonDatacenter::sFILE_OUTPUT = "";
string CommonDatacenter::sFILE_INPUT = "";

EnumCopyTradeMode CommonDatacenter::s_copyTradeMode = eCPT_MODE_UNKNOWN;

double CommonDatacenter::s_TodayStartEquity = 0;
uint CommonDatacenter::s_BuyPositionNum = 0;
uint CommonDatacenter::s_SellPositionNum = 0;