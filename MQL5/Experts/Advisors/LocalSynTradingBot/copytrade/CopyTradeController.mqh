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
    bool mIsInitSuccessed;

public:
    CopyTradeController()
    {
        mIsInitSuccessed = false;
    }

    ~CopyTradeController()
    {
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
        mIsInitSuccessed = isInitOk;
        return isInitOk;
    }

    void Terminate()
    {
        // chỉ khi init thành công mới save data
        if (m_MyTerminal && mIsInitSuccessed)
        {
            m_MyTerminal.Terminate();
        }

        // luôn luôn xóa file output
        mInOutMgr.Terminate();
    }

    void OnTimer()
    {
        // MQL5 có support OnTradeTransaction để detect position changed
        // MQL4 ko hỗ trợ, nên phải detect sự thay đổi của position theo từng timer.
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

                // Lấy loại position BUY / SELL
                ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
                if(dealType == DEAL_TYPE_BUY)
                    closedPosition.position_type = ePOSITION_TYPE_BUY;
                else if(dealType == DEAL_TYPE_SELL)
                    closedPosition.position_type = ePOSITION_TYPE_SELL;
                
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
 private:
    iPosition mPositions[];

    static int FindPositionIndex(iPosition &arr[], ulong ticket)
    {
        int total = ArraySize(arr);
        for(int i = 0; i < total; i++)
        {
            if(arr[i].position_ticket == ticket)
                return i;
        }
        return -1;
    }

    void CheckLocalPositionChanged()
    {
        // lấy snapshot hiện tại
        iPosition current_positions[];
        TerminalAPI::DoGetAllPosition(current_positions);

        int cur_total  = ArraySize(current_positions);
        int prev_total = ArraySize(mPositions);

        int i = 0, idx = 0;
        ulong ticket = 0;

        //==================================================
        // Detect CLOSED positions
        //==================================================
        iPosition closedPos;
        for(i = 0; i < prev_total; i++)
        {
            ticket = mPositions[i].position_ticket;
            idx = FindPositionIndex(current_positions, ticket);
            if(idx < 0)
            {
                closedPos = mPositions[i];
                closedPos.status = ePOSITION_STATUS_CLOSED;
                LOGD(">>> POSITION CLOSED: " + ToString(closedPos));
                m_MyTerminal.OnPositionClosed(closedPos);
            }
            else
            {
                if (current_positions[idx].volume < mPositions[i].volume)
                {
                    closedPos = mPositions[i];
                    closedPos.volume = mPositions[i].volume - current_positions[idx].volume;
                    closedPos.status = ePOSITION_STATUS_CLOSED;
                    LOGD(">>> POSITION PARTIAL CLOSED: " + ToString(closedPos));
                    m_MyTerminal.OnPositionClosed(closedPos);
                }
            }
        }

        //==================================================
        // Detect NEW positions
        //==================================================
        for(i = 0; i < cur_total; i++)
        {
            ticket = current_positions[i].position_ticket;
            idx = FindPositionIndex(mPositions, ticket);
            if(idx < 0)
            {
                LOGD(">>> POSITION ADDED: ticket=" + ToString(current_positions[i]));
                m_MyTerminal.OnPositionAdded(current_positions[i]);
            }
        }

        //==================================================
        // update snapshot
        //==================================================
        ArrayResize(mPositions, cur_total);
        for(i = 0; i < cur_total; i++)
        {
            mPositions[i] = current_positions[i];
        }
    }
#endif
};