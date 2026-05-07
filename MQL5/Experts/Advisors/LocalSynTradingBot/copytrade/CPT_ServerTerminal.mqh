#include "../common/Types.mqh"
#include "CPT_LocalTerminal.mqh"

class CPT_ServerTerminal : public CPT_LocalTerminal
{
public:
	CPT_ServerTerminal() : CPT_LocalTerminal() {}
    void OnPositionAdded(iPosition& newPos) {}
    void OnPositionClosed(iPosition& newPos) {}

	void Terminate() override
	{
		
	}
	
    void DoPoll() override
	{
		
	}
};