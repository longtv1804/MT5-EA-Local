#include "Types.mqh"

class TerminalApi
{
private:

public:
	TerminalApi() {}
	~TerminalApi() {}
	
	PositionInfo DoGetPosition(ulong position_ticket)
	{

	}
	PositionInfo[] DoGetAllPositions()
	{
		
	}

	void DoEndPosition(ulong position_ticket)
	{
	   RemovePositionByTicket(g_OpenPositions, position_ticket);
	}

	void DoEndAllPositions()
	{
	   ArrayResize(g_OpenPositions, 0);
	}
};