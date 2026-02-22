#include "Terminal.mqh"
#include "LocalTerminal.mqh"
#include "Types.mqh"
#include "Utils.mqh"

class RemoteTerminal  : public Terminal
{
private:
	LocalTerminal *m_pLocalTerminal = NULL;

public:
	RemoteTerminal(LocalTerminal *pLocalTerminal) : m_pLocalTerminal(pLocalTerminal) {}
	~RemoteTerminal() {}

	void init()
	{
		InitFiles();
	}

	void DoPoll()
	{
		string jsonData = PollData();
		if(jsonData != "")
		{
			// process json data
			MqlTradeRequest request;
			MqlTradeResult result;
			if(JsonToTradeRequest(jsonData, request))
			{
				if(OrderSend(request, result))
				{
					// update local terminal positions
					if(result.retcode == TRADE_RETCODE_DONE)
					{
						iPosition posInfo;
						FilliPositionFromTradeResult(posInfo, result);
						m_pLocalTerminal.AddPosition(m_pLocalTerminal.m_OpenPositions, posInfo);
					}
				}
			}
		}
	}

	/**********************************************************************************
	*
	*  receive data from the remote terminal
	*
	***********************************************************************************/
private:
	string PollData()
	{
		if (FILE_INPUT == "")
		{
			LOGE("FILE_INPUT is empty");
			return("");
		}

		string result = "";
		int handle = FileOpen(FILE_INPUT, FILE_READ|FILE_TXT|FILE_COMMON);
		if(handle != INVALID_HANDLE)
		{
			result = FileReadString(handle);
			FileClose(handle);
		}
		return(result);
	}

};