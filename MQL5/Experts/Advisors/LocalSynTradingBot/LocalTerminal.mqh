#include "Terminal.mqh"
#include "TerminalApi.mqh"
#include "RemoteTerminal.mqh"
#include "Types.mqh"
#include "Utils.mqh"

class LocalTerminal : public Terminal
{
public:
	LocalTerminal() {}
	~LocalTerminal() {}

	void init()
	{
		InitFiles();
	}

	/**********************************************************************************
	*
	*  send data to the remote terminal
	*
	***********************************************************************************/
	string FILE_OUTPUT = "";
	void InitFiles()
	{
		string server_name = AccountInfoString(ACCOUNT_SERVER);
		string server_lower = StringToLower(server_name);

		if(StringFind(server_lower, "exness") >= 0)
		{
			FILE_OUTPUT = "ex_data_exchange.txt";
		}
		else if(StringFind(server_lower, "xmglobal") >= 0)
		{
			FILE_OUTPUT = "xm_data_exchange.txt";
		}
		else
		{
			LOGE("Unknown broker: ", server_name);
		}
	}

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
		if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
		{
			if(!HistoryDealSelect(trans.deal))
				return;

			long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

			if(entry == DEAL_ENTRY_IN)
			{
				TradeInfo info;

				info.position_ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
				info.deal_ticket     = trans.deal;
				info.symbol          = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
				info.volume          = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
				info.price_open      = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
				info.time_open       = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
				info.status          = "OPEN";
				info.reason          = "OPEN";

				if(PositionSelectByTicket(info.position_ticket))
				{
					info.position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
				}

				AddTrade(info);

				Print(">>> NEW POSITION OPENED: ", info.position_ticket);
			}

			if(entry == DEAL_ENTRY_OUT)
			{
				TradeInfo info;

				info.position_ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
				info.deal_ticket     = trans.deal;
				info.symbol          = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
				info.volume          = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
				info.price_close     = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
				info.time_close      = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
				info.status          = "CLOSED";

				info.reason = HistoryDealGetInteger(trans.deal, DEAL_REASON);

				AddTrade(info);

				Print(">>> POSITION CLOSED: ", info.position_ticket,
					" | Reason: ", info.reason);
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