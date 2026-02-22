#include "Types.mqh"
#include "Constanst.mqh"
#include "Utils.mqh"

class Terminal
{
protected:
	iPosition m_OpenPositions[];

	Terminal() {}
	~Terminal() {}

	string FILE_OUTPUT;
	string FILE_INPUT;
	void InitFiles()
	{
		string server_name = AccountInfoString(ACCOUNT_SERVER);
		StringToLower(server_name);

		if(StringFind(server_name, "exness") >= 0)
		{
			FILE_OUTPUT = EXNESS_TO_XM_FILE;
			FILE_INPUT = XM_TO_EXNESS_FILE;
		}
		else if(StringFind(server_name, "xmglobal") >= 0)
		{
			FILE_OUTPUT = XM_TO_EXNESS_FILE;
			FILE_INPUT = EXNESS_TO_XM_FILE;
		}
		else
		{
			LOGE("Unknown broker: " + server_name);
			FILE_OUTPUT = "";
			FILE_INPUT = "";
		}
	}

	void AddPosition(iPosition &info)
	{
		int size = ArraySize(m_OpenPositions);
		ArrayResize(m_OpenPositions, size + 1);
		m_OpenPositions[size] = info;
	}

	void RemovePositionByTicket(ulong position_ticket)
	{
		int size = ArraySize(m_OpenPositions);
		for(int i = 0; i < size; i++)
		{
			if(m_OpenPositions[i].position_ticket == position_ticket)
			{
				for(int j = i; j < size - 1; j++)
				{
					m_OpenPositions[j] = m_OpenPositions[j + 1];
				}
				ArrayResize(m_OpenPositions, size - 1);
				break;
			}
		}
	}

	void UpdatePosition(iPosition &info)
	{
		int size = ArraySize(m_OpenPositions);
		for(int i = 0; i < size; i++)
		{
			if(m_OpenPositions[i].position_ticket == info.position_ticket)
			{
				m_OpenPositions[i] = info;
				break;
			}
		}
	}

	iPosition GetPositionsByTicket(ulong position_ticket)
	{
		int size = ArraySize(m_OpenPositions);
		int idx = 0;
		for(idx = 0; idx < size; idx++)
		{
			if(m_OpenPositions[idx].position_ticket == position_ticket)
			{
				break;
			}
		}
		return m_OpenPositions[idx];
	}

	double GetVolume()
	{
		double sum = 0;
		for (int i = 0; i < ArraySize(m_OpenPositions); i++)
		{
			sum += m_OpenPositions[i].volume;
		}
		return sum;
	}

public:
	void init()
	{
		InitFiles();
	}
};
