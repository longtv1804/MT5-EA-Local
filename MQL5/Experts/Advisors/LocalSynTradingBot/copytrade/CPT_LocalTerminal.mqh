#include "../common/Terminal.mqh"
#include "../common/TerminalApi.mqh"
#include "../common/CommonDatacenter.mqh"
#include "../common/Types.mqh"
#include "../common/Utils.mqh"
#include "CPT_InOutManager.mqh"

class CPT_LocalTerminal
{
protected:
    CPT_InOutManager *m_pInOutManager;

/**********************************************************************************
*
*  init/terminate function
*
***********************************************************************************/
public:
    CPT_LocalTerminal() : m_pInOutManager(NULL) {}

    ~CPT_LocalTerminal() {}

    virtual bool Init(CPT_InOutManager* inOutController)
    {
        m_pInOutManager = inOutController;
        return true;
    }

    virtual void Terminate() = 0;

/**********************************************************************************
*
*   OnLocal_OnTradeTransaction
*
***********************************************************************************/
public:
    virtual void OnPositionAdded(iPosition& newPosition) {}
    virtual void OnPositionClosed(iPosition& newPosition) {}

    void OnLocal_OnTradeTransaction(const MqlTradeTransaction& trans,
                            const MqlTradeRequest& request,
                            const MqlTradeResult& result)
    {
        LOGD("TRANS: " + EnumToString(trans.type));
        if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
        {
            if(!HistoryDealSelect(trans.deal))
            {
                return;
            }

            long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_IN)
            {
                iPosition newPosition;
                ZeroMemory(newPosition);

                ulong positionId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);

                newPosition.position_ticket = positionId;
                newPosition.symbol          = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
                newPosition.volume          = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
                newPosition.price_open      = HistoryDealGetDouble(trans.deal, DEAL_PRICE);

                // Lấy loại position BUY / SELL
                ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);

                if(dealType == DEAL_TYPE_BUY)
                    newPosition.position_type = ePOSITION_TYPE_BUY;
                else if(dealType == DEAL_TYPE_SELL)
                    newPosition.position_type = ePOSITION_TYPE_SELL;

                // Position đang mở
                newPosition.status = ePOSITION_STATUS_OPEN;

                LOGD(">>> POSITION OPENED: " + ToString(newPosition));

                // callback
                OnPositionAdded(newPosition);
            }
            else if(entry == DEAL_ENTRY_OUT)
            {
                iPosition closedPosition;
                ZeroMemory(closedPosition);

                closedPosition.position_ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
                closedPosition.symbol          = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
                closedPosition.volume          = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
                closedPosition.price_close     = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
                closedPosition.status          = ePOSITION_STATUS_CLOSED;
                closedPosition.close_reason    = ConvertCloseReason((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON));
                LOGD(">>> POSITION CLOSED: " + ToString(closedPosition));
                OnPositionClosed(closedPosition);
            }
            else
            {
                LOGD(">>> POSITION CHANGED: " + IntegerToString(entry));
            }
        }
    }

/**********************************************************************************
*
*  Poll
*
***********************************************************************************/
public:
    virtual void DoPoll() = 0;
};