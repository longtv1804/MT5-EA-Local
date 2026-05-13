#include "../common/Utils.mqh"
#include "../common/Types.mqh"
#include "../common/CommonDatacenter.mqh"
#include "CPT_LocalTerminal.mqh"
#include "CPT_ServerTerminal.mqh"
#include "CPT_ClientTerminal.mqh"
#include "CPT_InOutManager.mqh"
class CopyTradeController
{
    CPT_LocalTerminal* m_MyTerminal;
    CPT_InOutManager mInOutMgr;

public:
    CopyTradeController()
    {
    }

    ~CopyTradeController()
    {
        Terminate();
        if (m_MyTerminal)
        {
            delete m_MyTerminal;
            m_MyTerminal = NULL;
        }
    }

    bool Init(int terminal_mode, double weight)
    {
        // init seed number for MathRand()
        MathSrand(GetTickCount());
        
        CommonDatacenter::s_copyTradeMode = eCPT_MODE_UNKNOWN;
        if (terminal_mode == eCPT_MODE_SERVER)
        {
            CommonDatacenter::s_copyTradeMode = eCPT_MODE_SERVER;
            m_MyTerminal = new CPT_ServerTerminal();
        }
        else
        {
            CommonDatacenter::s_copyTradeMode = eCPT_MODE_CLIENT;
            m_MyTerminal = new CPT_ClientTerminal(weight);
        }

        bool isInitOk = false;
        
        isInitOk = m_MyTerminal.Init(&mInOutMgr);
        if (!isInitOk)
        {
            return false;
        }

        isInitOk = mInOutMgr.Init();
        return isInitOk;
    }

    void Terminate()
    {
        m_MyTerminal.Terminate();
        mInOutMgr.Terminate();
    }

    void OnTimer()
    {
#ifdef __MQL5__
        m_MyTerminal.DoPoll();
#else
        CheckLocalPositionChanged();
        m_MyTerminal.DoPoll();
#endif
    }

/**********************************************************************************
*
*  MQL5: function checking Position change
*
***********************************************************************************/
#ifdef __MQL5__
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
                newPosition.magic_number =  HistoryDealGetInteger(trans.deal, DEAL_MAGIC);

                LOGD(">>> POSITION OPENED: " + ToString(newPosition));

                // callback
                m_MyTerminal.OnPositionAdded(newPosition);
            }
            else if(entry == DEAL_ENTRY_OUT)
            {
                iPosition closedPosition;
                ZeroMemory(closedPosition);

                closedPosition.position_ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
                closedPosition.symbol          = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
                closedPosition.volume          = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
                closedPosition.magic_number    =  HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
                closedPosition.price_close     = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
                closedPosition.status          = ePOSITION_STATUS_CLOSED;
                closedPosition.close_reason    = ConvertCloseReason((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON));
                LOGD(">>> POSITION CLOSED: " + ToString(closedPosition));
                m_MyTerminal.OnPositionClosed(closedPosition);
            }
            else
            {
                LOGD(">>> POSITION CHANGED: " + IntegerToString(entry));
            }
        }
    }

/**********************************************************************************
*
*  MQL4: function checking Position change
*
***********************************************************************************/
 #else
    void CheckLocalPositionChanged()
    {

    }
#endif
};