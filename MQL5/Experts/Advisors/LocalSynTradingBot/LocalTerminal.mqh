#include "Terminal.mqh"
#include "TerminalApi.mqh"
#include "Types.mqh"
#include "Utils.mqh"

class LocalTerminal : public Terminal
{
public:
	LocalTerminal() {}
	~LocalTerminal() {}

	/**********************************************************************************
	*
	*  send data to the remote terminal
	*
	***********************************************************************************/

	void SendData(string jsonData)
	{
		if (FILE_OUTPUT == "")
		{
			LOGE("FILE_OUTPUT is empty");
			return;
		}
		int handle = FileOpen(FILE_OUTPUT, FILE_WRITE|FILE_TXT|FILE_COMMON);
		if(handle != INVALID_HANDLE)
		{
			FileWrite(handle, jsonData);
			FileClose(handle);
		}
	}

	/**********************************************************************************
	*
	*  OnLocal fucntions
	*		trigger when there some thing change in the local terminal
	*
	***********************************************************************************/
	void OnLocal_OnTradeTransaction(const MqlTradeTransaction& trans,
							const MqlTradeRequest& request,
							const MqlTradeResult& result)
	{
		LOGD("TRANS: " + EnumToString(trans.type));
		if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
		{
			LOGD(ToString(trans));
			LOGD(ToString(request));
			LOGD(ToString(result));
			
			iPosition currPositions[];
			DoGetAllPosition(currPositions);
			if(ArraySize(currPositions) == 0)
			{
				LOGD("NOW Position: No opened positions");
			}
			else
			{
				for(int i = 0; i < ArraySize(currPositions); i++)
				{
					LOGD("NOW Position[" + IntegerToString(i) + "] " + ToString(currPositions[i]));
				}
			}

			if(!HistoryDealSelect(trans.deal))
				return;

			long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

			if(entry == DEAL_ENTRY_IN)
			{
				iPosition info;
				ZeroMemory(info);

				info.position_ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
				info.deal_ticket     = trans.deal;
				info.symbol          = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
				info.volume          = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
				info.price_open      = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
				info.time_open       = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
				info.status          = ePOSITION_STATUS_OPEN;
				info.open_reason     = (ENUM_POSITION_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);

				if(PositionSelectByTicket(info.position_ticket))
				{
					info.position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
				}

				AddPosition(info);

				LOGD(">>> POSITION OPENED: " + ToString(info));
			}
			else if(entry == DEAL_ENTRY_OUT)
			{
				iPosition info;
				ZeroMemory(info);

				info.position_ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
				info.deal_ticket     = trans.deal;
				info.symbol          = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
				info.volume          = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
				info.price_close     = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
				info.time_close      = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
				info.status          = ePOSITION_STATUS_CLOSED;
				info.close_reason    = (EnumCloseReason)HistoryDealGetInteger(trans.deal, DEAL_REASON);

				AddPosition(info);

				LOGD(">>> POSITION CLOSED: " + ToString(info));
			}
			else
			{
				LOGD(">>> POSITION CHANGED: ");
			}
		}
	}

	void OnLocal_PositionChange() {}

	/**********************************************************************************
	*
	*  OnRemote fucntions
	*		trigger when remote data is received
	*
	***********************************************************************************/
	void OnRemote_PositionChange() {}
};