#include "CPT_Strategy.mqh"
#include "../common/Types.mqh"
#include "../common/TerminalApi.mqh"
#include "../common/TradeUtils.mqh"
#include "../common/Logging.mqh"
#include "../common/CommonDatacenter.mqh"
#include "../queue/EventUtils.mqh"

/*
*    vào lệnh bình thường cùng chiều và theo volume*(trọng số)
*/
class CPT_Strategy_DefaultPlan : public CPT_Strategy
{
protected:
    bool mEnableBuySellInSameTime;
    EnumTakeProfitMode mTakeProfitMode;
    double mTakeProfitDistance;
    double mStopLostDistance;

    void SetDefaultStrategyParams (ByteBuffer& params)
    {
        mEnableBuySellInSameTime = params.ReadBool();
        mTakeProfitMode     =   (EnumTakeProfitMode)params.ReadInt();
        mTakeProfitDistance =   params.ReadDouble();
        mStopLostDistance   =   params.ReadDouble();
        LOGD(   ""  + (string)mEnableBuySellInSameTime + " " + (string)mTakeProfitMode + 
                " " + (string)mTakeProfitDistance + " " + (string)mStopLostDistance);
    }

    /**********************************************************************************
    *
    *   and functions for handle events
    *
    ***********************************************************************************/

    /*------------------EV_ADD_NEW_POSITION--------------------------*/
    /*                  EV_ADD_NEW_POSITION_DONE                     */
    virtual void Do_OpendPosition(const Event &ev) override
    {
        CopyTradeReqData reqData = EventUtils::ToCopyTradeReqData(ev);
        // generate pseudo unique magic number
        reqData.tracking_number = ((ulong)MathRand() << 16) | (ulong)MathRand();
        bool res = TerminalAPI::Do_OpendPosition(reqData);
        if (res == true)
        {
            Event pendingEv = ObtainEvent(EV_PENDING_WAITING_NEW_POSITION);
            pendingEv.arg_ulong_1 = reqData.server_ticket;
            pendingEv.arg_ulong_2 = reqData.tracking_number;
            SendPendingEvent(pendingEv);
        }
    }
    virtual void On_OpendPositionDone(const Event &ev) override
    {
        EnumEventState closePosState = (EnumEventState)ev.arg_int_1;
        if (closePosState == EnumEventState::EVS_WAIITING_SUCCESS)
        {
            mSession.AddCopyTradePosition(ev.arg_ulong_1, ev.arg_ulong_2);
        }
        else
        {
            mSession.AddCopyTradePosition(ev.arg_ulong_1, 0);
        }
    }

    /*------------------EV_CLOSED_POSITION--------------------------*/
    /*                  EV_CLOSED_POSITIOND_DONE                    */
    virtual void Do_ClosePosition(const Event &ev) override
    {
        CopyTradeReqData reqData = {0};
        reqData.server_ticket = ev.arg_ulong_1;
        reqData.target_ticket = ev.arg_ulong_2;
        bool res = TerminalAPI::Do_ClosePosition(reqData);
        if (res == true)
        {
            Event pendingEv = ObtainEvent(EV_PENDING_WAITING_CLOSE_POSITION);
            pendingEv.arg_ulong_1 = ev.arg_ulong_1;
            pendingEv.arg_ulong_2 = ev.arg_ulong_2;
            SendPendingEvent(pendingEv);
        }
    }
    virtual void On_ClosePositionDone(const Event &ev) override
    {
        EnumEventState closePosState = (EnumEventState)ev.arg_int_1;
        if (closePosState == EnumEventState::EVS_WAIITING_SUCCESS)
        {
            mSession.RemoveCopyTradePosition(ev.arg_ulong_1, ev.arg_ulong_2);
        }
        else
        {
            string email_title = "close position " + (string)ev.arg_ulong_2 + " FAILED";
            string email_content = "close position get failed:\n"
                                    "client-ticket: " + (string)ev.arg_ulong_2 + "\n"
                                    "server-ticket: " + (string)ev.arg_ulong_1 ;
            TerminalAPI::SendEmail(email_title, email_content);
        }
    }

    /**********************************************************************************
    *
    *   Pending Events
    *   and functions for handle Pending Events
    *
    ***********************************************************************************/

    /*--------------EV_PENDING_CLOSE_NOT_ADDED_POSITION----------*/
    virtual void On_WaitingCloseNotAddedPosDone(const Event &pendingEv) override
    {
        STRATEGY_LOGD("server-ticket=" + (string)pendingEv.arg_ulong_1 + " target-ticket=" +  (string)pendingEv.arg_ulong_2);
        if (pendingEv.state == EnumEventState::EVS_WAIITING_SUCCESS)
        {
            Event ev = ObtainEvent(EV_CLOSED_POSITION);
            ev.arg_int_1 = (int)pendingEv.state;
            ev.arg_ulong_1 = pendingEv.arg_ulong_1;
            ev.arg_ulong_2 = pendingEv.arg_ulong_2;
            SendEvent(ev);
        }
    }

    /*----------------EV_PENDING_WAITING_NEW_POSITION------------*/
    virtual void On_WaitingNewPosDone(const Event &pendingEv) override
    {
        STRATEGY_LOGD("server-ticket=" + (string)pendingEv.arg_ulong_1 + " new-ticket=" +  (string)pendingEv.arg_ulong_2);
        Event ev = ObtainEvent(EV_ADD_NEW_POSITION_DONE);
        ev.arg_int_1 = (int)pendingEv.state;
        ev.arg_ulong_1 = pendingEv.arg_ulong_1;     // server-ticket
        ev.arg_ulong_2 = pendingEv.arg_ulong_2;     // client new ticket
        SendEvent(ev);
    }

    /*----------------EV_PENDING_WAITING_CLOSE_POSITION-----------*/
    virtual void On_WaitingClosePosDone(const Event &pendingEv) override
    {
        Event ev = ObtainEvent(EV_CLOSED_POSITION_DONE);
        ev.arg_int_1 = (int)pendingEv.state;
        ev.arg_ulong_1 = pendingEv.arg_ulong_1;     // server-ticket
        ev.arg_ulong_2 = pendingEv.arg_ulong_2;     // client new ticket
        SendEvent(ev);
    }

    /**********************************************************************************
    *
    *   HandleEvent
    *   HandlePendingEventDone
    *
    ***********************************************************************************/
public:
    CPT_Strategy_DefaultPlan(EnumStrategyPositionType type, double weight) 
    : CPT_Strategy(type, weight)
    {
    }

    ~CPT_Strategy_DefaultPlan()
    {
    }

    virtual void HandleEvent(const Event &ev) override
    {
        if(ev.state != EnumEventState::EVS_DISPATCHING)
        {
            STRATEGY_LOGE("Event is in wrong state " + (string)ev.eventId + " " + (string)ev.state);
            return;
        }
        STRATEGY_LOGD("EventId=" + EventToString(ev.eventId));
        switch (ev.eventId)
        {
            case EV_ADD_NEW_POSITION:
                Do_OpendPosition(ev);
                break;
            case EV_ADD_NEW_POSITION_DONE:
                On_OpendPositionDone(ev);
                break;
            case EV_CLOSED_POSITION:
                Do_ClosePosition(ev);
                break;
            case EV_CLOSED_POSITION_DONE:
                On_ClosePositionDone(ev);
                break;
            case EV_STRATEGY_UPDATE_PARAMS:
            {
                ByteBuffer buffer(ev.data);
                SetDefaultStrategyParams(buffer);
                break;
            }
            default:
                STRATEGY_LOGE("Unhandle eventId = " + (string)ev.eventId);
                break;
        }
    }

    virtual void HandlePendingEventDone(const Event &pendingEv) override
    {
        if(pendingEv.state != EnumEventState::EVS_WAIITING_SUCCESS && 
            pendingEv.state != EnumEventState::EVS_WAITING_FAILED &&
            pendingEv.state != EnumEventState::EVS_TIMEOUT)
        {
            STRATEGY_LOGD("Event is NOT SUCCESSED: id=" + (string)pendingEv.eventId + " state=" + (string)pendingEv.state);
            return;
        }
        STRATEGY_LOGD("EventId=" + EventToString(pendingEv.eventId) + " EvState=" + (string)pendingEv.state);
        switch (pendingEv.eventId)
        {
            case EV_PENDING_CLOSE_NOT_ADDED_POSITION:
                On_WaitingCloseNotAddedPosDone(pendingEv);
                break;
            case EV_PENDING_WAITING_NEW_POSITION:
                On_WaitingNewPosDone(pendingEv);
                break;
            case EV_PENDING_WAITING_CLOSE_POSITION:
                On_WaitingClosePosDone(pendingEv);
                break;
            default:
                STRATEGY_LOGE("Unhandle eventId = " + (string)pendingEv.eventId);
                break;
        }
    }

    /**********************************************************************************
    *
    *   local Possions changed
    *
    ***********************************************************************************/
public:
    virtual void OnLocal_PositionAdded(const iPosition& newPos) override
    {
        int queue_size = PendingEventList::GetInstance().Size();

        // sau khi position added: cần check lại PendingList và update event thành SUCCESS
        bool isCopyTradePositionAdded = false;
        for (int i = 0; i < queue_size; i++)
        {
            Event* ev = PendingEventList::GetInstance().At(i);

            if (ev.state == EnumEventState::EVS_WAITING && ev.eventId == EV_PENDING_WAITING_NEW_POSITION
                && ev.arg_ulong_2 == newPos.magic_number)
            {
                isCopyTradePositionAdded = true;
                ev.state = EnumEventState::EVS_WAIITING_SUCCESS;
                ev.arg_ulong_2 = newPos.position_ticket;
            }
            else if (ev.state == EnumEventState::EVS_WAITING && ev.eventId == EV_PENDING_CLOSE_NOT_ADDED_POSITION
                    && ev.arg_ulong_2 == newPos.magic_number)
            {
                ev.state = EnumEventState::EVS_WAIITING_SUCCESS;
                ev.arg_ulong_2 = newPos.position_ticket;
            }
        }

        // nếu ko phải postion cho copy trade, thì add nó ở dạng [0, pos-id]
        if (isCopyTradePositionAdded == false)
        {
            mSession.AddCopyTradePosition(0, newPos.position_ticket);
        }
    }

    virtual void OnLocal_PositionClosed(const iPosition& closedPos) override
    {
        // check lại PendingList và update event thành SUCCESS
        int queue_size = PendingEventList::GetInstance().Size();
        bool isCopyTradePositionClosed = false;
        for (int i = 0; i < queue_size; i++)
        {
            Event* pendingEv = PendingEventList::GetInstance().At(i);

            if (pendingEv.state == EnumEventState::EVS_WAITING && pendingEv.eventId == EV_PENDING_WAITING_CLOSE_POSITION
                && pendingEv.arg_ulong_2 == closedPos.position_ticket)
            {
                isCopyTradePositionClosed = true;
                pendingEv.state = EnumEventState::EVS_WAIITING_SUCCESS;
            }
        }

        // nếu ko phải postion cho copy trade, thì thử remove nó
        if (isCopyTradePositionClosed == false)
        {
            ulong server_ticket = mSession.GetServerTicket(closedPos.position_ticket);
            // trường hợp user đóng mất ticket nằm trong TradingMap
            if (server_ticket != 0)
            {
                mSession.RemoveCopyTradePosition(server_ticket, closedPos.position_ticket);
            }
            // trường hợp ticket không nằm trong TradingMap
            else
            {
                mSession.RemoveCopyTradePosition(0, closedPos.position_ticket);
            }
        }
    }

    /**********************************************************************************
    *
    *   local Possions changed
    *
    ***********************************************************************************/
public:
    virtual void OnServer_NewPositionAdded(const iPosition &newPos) override
    {
        if (mSession.HasServerTicket(newPos.position_ticket))
        {
            STRATEGY_LOGE("server-ticket is already in the trading map: " + (string)newPos.position_ticket);
            return;
        }

        // chỉ vào lệnh sell hoặc buy, ko vào cả 2 cùng lúc
        if (mEnableBuySellInSameTime == false &&
            ((newPos.position_type == ePOSITION_TYPE_BUY && CommonDatacenter::s_SellPositionNum > 0) ||
             (newPos.position_type == ePOSITION_TYPE_SELL && CommonDatacenter::s_BuyPositionNum > 0)))
        {
            LOGD("ignore, NOT allow buy/sell in the same time");
            mSession.AddCopyTradePosition(newPos.position_ticket, 0);
            return;
        }

        CopyTradeReqData reqData = {0};
        reqData.server_ticket = newPos.position_ticket;
        reqData.position_type = newPos.position_type;
        reqData.volume = TradeUtils::NormalizeVolume(_Symbol, newPos.volume * mSession.GetWeight());
        Event ev = ObtainEvent(EV_ADD_NEW_POSITION);
        EventUtils::ToData(ev, reqData);
        SendEvent(ev);
    }

    virtual void OnServer_PositionClosed(const iPosition &closedPos) override
    {
        ulong target_ticket = mSession.GetClientTicket(closedPos.position_ticket);
        if (target_ticket == 0)
        {
            // trong trường hợp event add new position chưa xong,
            // thì sẽ ko thể tìm thấy target position
            bool hasPendingAddNewPosEvent = false;
            int queue_size = PendingEventList::GetInstance().Size();
            for (int i = 0; i < queue_size; i++)
            {
                const Event* pendingEv = PendingEventList::GetInstance().At(i);
                if (pendingEv.eventId == EV_PENDING_WAITING_NEW_POSITION
                    && pendingEv.arg_ulong_1 == closedPos.position_ticket)
                {
                    if (pendingEv.state == EnumEventState::EVS_WAITING || pendingEv.state == EnumEventState::EVS_WAIITING_SUCCESS)
                    {
                        hasPendingAddNewPosEvent = true;
                        STRATEGY_LOGD("the target has not done placing position, server-ticket" + (string)closedPos.position_ticket);
                        Event newPendingEv = ObtainEvent(EV_PENDING_CLOSE_NOT_ADDED_POSITION);
                        newPendingEv.arg_ulong_1 = closedPos.position_ticket;       // set server ticket
                        newPendingEv.arg_ulong_2 = pendingEv.arg_ulong_2;           // set magic number
                        SendPendingEvent(newPendingEv);
                        
                        // trong trường hợp WAITING_NEW_POSITION đang ở state WAITING: thì addedPeningEv cũng phải để là WAITING
                        //                                                    SUCCESS: thì addedPeningEv cũng phải để là SUCCESS
                        Event *addedPeningEv = PendingEventList::GetInstance().At(PendingEventList::GetInstance().Size() - 1);
                        addedPeningEv.state = pendingEv.state;
                    }
                    else
                    {
                        STRATEGY_LOGD("ignore close pos for server-ticket[" + (string)closedPos.position_ticket + "] state=" + (string)pendingEv.state);
                    }
                    break;
                }
            }

            // trường hợp ko tìm thấy trong pendingList thì có thể đặt lệnh failed
            // thử remove trong session
            if (hasPendingAddNewPosEvent == false)
            {
                STRATEGY_LOGD("the target not found, server-ticket" + (string)closedPos.position_ticket);
                // thử remove data trong session
                mSession.RemoveCopyTradePosition(closedPos.position_ticket, 0);
            }
        }
        else
        {
            Event ev = ObtainEvent(EV_CLOSED_POSITION);
            ev.arg_ulong_1 = closedPos.position_ticket;
            ev.arg_ulong_2 = target_ticket;
            SendEvent(ev);
        }
    }
};