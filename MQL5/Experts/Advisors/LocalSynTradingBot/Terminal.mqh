#include <Trade\PositionInfo.mqh>
#include "Types.mqh"

class Terminal
{
	protected:
		PositionInfo m_OpenPositions[];

		Terminal() {}
		~Terminal() {}


	void AddPosition(PositionInfo arr[], PositionInfo &info)
	{
		int size = ArraySize(arr);
		ArrayResize(arr, size + 1);
		arr[size] = info;
	}

	void RemovePositionByTicket(PositionInfo arr[], ulong position_ticket)
	{
		int size = ArraySize(arr);
		for(int i = 0; i < size; i++)
		{
			if(arr[i].position_ticket == position_ticket)
			{
				for(int j = i; j < size - 1; j++)
				{
					arr[j] = arr[j + 1];
				}
				ArrayResize(arr, size - 1);
				break;
			}
		}
	}

	void UpdatePosition(PositionInfo arr[], PositionInfo &info)
	{
		int size = ArraySize(arr);
		for(int i = 0; i < size; i++)
		{
			if(arr[i].position_ticket == info.position_ticket)
			{
				arr[i] = info;
				break;
			}
		}
	}

	void GetPositionsByTicket( PositionInfo info[], ulong position_ticket)
	{
		int size = ArraySize(g_OpenPositions);
		for(int i = 0; i < size; i++)
		{
			if(g_OpenPositions[i].position_ticket == position_ticket)
			{
				info = g_OpenPositions[i];
				break;
			}
		}
	}
};
