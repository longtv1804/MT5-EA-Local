#include "../common/Types.mqh"
#include "../common/Utils.mqh"
#include "../common/Logging.mqh"
#include "../common/TradeUtils.mqh"
#include "../queue/Event.mqh"
#include "../queue/EventUtils.mqh"
#include "CPT_LocalTerminal.mqh"
#include "CPT_CopyTradeSession.mqh"
#include "CPT_Strategy.mqh"
#include "CPT_Strategy_Factory.mqh"

class CPT_ClientTerminal : public CPT_LocalTerminal
{
private:
    CPT_CopyTradeSession mSession;

    /**********************************************************************************
    *
    *   Event
    *   and functions for handle events
    *
    ***********************************************************************************/
    enum EnumCopyTradeEvent
    {
        EV_ADD_NEW_POSITION = 1,
        EV_ADD_NEW_POSITION_DONE,
        EV_CLOSED_POSITION,
        EV_CLOSED_POSITION_DONE,
        EV_PENDING_CLOSE_NOT_ADDED_POSITION,
        EV_PENDING_WAITING_NEW_POSITION,
        EV_PENDING_WAITING_CLOSE_POSITION
    };

    static string EventToString(int evid)
    {
        switch (evid)
        {
            case EV_ADD_NEW_POSITION:       return "EV_ADD_NEW_POSITION";
            case EV_ADD_NEW_POSITION_DONE:  return "EV_ADD_NEW_POSITION_DONE";
            case EV_CLOSED_POSITION:        return "EV_CLOSED_POSITION";
            case EV_CLOSED_POSITION_DONE:   return "EV_CLOSED_POSITION_DONE";
            case EV_PENDING_CLOSE_NOT_ADDED_POSITION:   return "EV_PENDING_CLOSE_NOT_ADDED_POSITION";
            case EV_PENDING_WAITING_NEW_POSITION:       return "EV_PENDING_WAITING_NEW_POSITION";
            case EV_PENDING_WAITING_CLOSE_POSITION:     return "EV_PENDING_WAITING_CLOSE_POSITION";
            default: return (string) evid;
        }
    }

    /*------------------EV_ADD_NEW_POSITION--------------------------*/
    /*                  EV_ADD_NEW_POSITION_DONE                     */
    void DoCopyTrade_OpendPosition(const Event &ev)
    {
        CopyTradeReqData reqData = EventUtils::ToCopyTradeReqData(ev);
        // generate pseudo unique magic number
        reqData.tracking_number = ((ulong)MathRand() << 16) | (ulong)MathRand();
        bool res = TerminalAPI::DoCopyTrade_OpendPosition(reqData);
        if (res == true)
        {
            Event pendingEv = ObtainEvent(EV_PENDING_WAITING_NEW_POSITION);
            pendingEv.arg_ulong_1 = reqData.server_ticket;
            pendingEv.arg_ulong_2 = reqData.tracking_number;
            SendPendingEvent(pendingEv);
        }
    }
    void OnCopyTrade_OpendPositionDone(const Event &ev)
    {
        mSession.AddCopyTradePosition(ev.arg_ulong_1, ev.arg_ulong_2);
    }

    /*------------------EV_CLOSED_POSITION--------------------------*/
    /*                  EV_CLOSED_POSITIOND_DONE                    */
    void DoCopyTrade_ClosePosition(const Event &ev)
    {
        CopyTradeReqData reqData = {0};
        reqData.server_ticket = ev.arg_ulong_1;
        reqData.target_ticket = ev.arg_ulong_2;
        bool res = TerminalAPI::DoCopyTrade_ClosePosition(reqData);
        if (res == true)
        {
            Event pendingEv = ObtainEvent(EV_PENDING_WAITING_CLOSE_POSITION);
            pendingEv.arg_ulong_1 = ev.arg_ulong_1;
            pendingEv.arg_ulong_2 = ev.arg_ulong_2;
            SendPendingEvent(pendingEv);
        }
    }
    void OnCopyTrade_ClosePositionDone(const Event &ev)
    {
        mSession.RemoveCopyTradePosition(ev.arg_ulong_1, ev.arg_ulong_2);
    }

    /**********************************************************************************
    *
    *   Pending Events
    *   and functions for handle Pending Events
    *
    ***********************************************************************************/

    /*--------------EV_PENDING_CLOSE_NOT_ADDED_POSITION----------*/
    void OnCopyTrade_WaitingCloseNotAddedPosDone(const Event &pendingEv)
    {
        LOGD("server-ticket=" + (string)pendingEv.arg_ulong_1 + " target-ticket=" +  (string)pendingEv.arg_ulong_2);
        Event ev = ObtainEvent(EV_CLOSED_POSITION);
        ev.arg_ulong_1 = pendingEv.arg_ulong_1;
        ev.arg_ulong_2 = pendingEv.arg_ulong_2;
        SendEvent(ev);
    }

    /*----------------EV_PENDING_WAITING_NEW_POSITION------------*/
    void OnCopyTrade_WaitingNewPosDone(const Event &pendingEv)
    {
        LOGD("server-ticket=" + (string)pendingEv.arg_ulong_1 + " new-ticket=" +  (string)pendingEv.arg_ulong_2);
        Event ev = ObtainEvent(EV_ADD_NEW_POSITION_DONE);
        ev.arg_ulong_1 = pendingEv.arg_ulong_1;     // server-ticket
        ev.arg_ulong_2 = pendingEv.arg_ulong_2;     // client new ticket
        SendEvent(ev);
    }

    /*----------------EV_PENDING_WAITING_CLOSE_POSITION-----------*/
    void OnCopyTrade_WaitingClosePosDone(const Event &pendingEv)
    {
        Event ev = ObtainEvent(EV_CLOSED_POSITION_DONE);
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

    void HandleEvent(const Event &ev) override
    {
        if(ev.state != EnumEventState::EVS_DISPATCHING)
        {
            LOGE("Event is in wrong state " + (string)ev.eventId + " " + (string)ev.state);
            return;
        }
        LOGD("EventId=" + EventToString(ev.eventId));
        switch (ev.eventId)
        {
            case EV_ADD_NEW_POSITION:
                DoCopyTrade_OpendPosition(ev);
                break;
            case EV_ADD_NEW_POSITION_DONE:
                OnCopyTrade_OpendPositionDone(ev);
                break;
            case EV_CLOSED_POSITION:
                DoCopyTrade_ClosePosition(ev);
                break;
            case EV_CLOSED_POSITION_DONE:
                OnCopyTrade_ClosePositionDone(ev);
                break;
            default:
                LOGE("Unhandle eventId = " + (string)ev.eventId);
                break;
        }
    }

    void HandlePendingEventDone(const Event &pendingEv) override
    {
        if(pendingEv.state != EnumEventState::EVS_WAIITING_SUCCESS)
        {
            LOGD("Event is NOT SUCCESSED: id=" + (string)pendingEv.eventId + " state=" + (string)pendingEv.state);
            return;
        }
        LOGD("EventId=" + EventToString(pendingEv.eventId));
        switch (pendingEv.eventId)
        {
            case EV_PENDING_CLOSE_NOT_ADDED_POSITION:
                OnCopyTrade_WaitingCloseNotAddedPosDone(pendingEv);
                break;
            case EV_PENDING_WAITING_NEW_POSITION:
                OnCopyTrade_WaitingNewPosDone(pendingEv);
                break;
            case EV_PENDING_WAITING_CLOSE_POSITION:
                OnCopyTrade_WaitingClosePosDone(pendingEv);
                break;
            default:
                LOGE("Unhandle eventId = " + (string)pendingEv.eventId);
                break;
        }
    }

    /**********************************************************************************
    *
    *   init/terminate
    *
    *
    ***********************************************************************************/
public:
    CPT_ClientTerminal(double weight) 
    :   CPT_LocalTerminal(),
        mSession(eCPT_MODE_CLIENT, 0, weight) 
    {
        SetConnectionState(eSERVER_CONN_STATE_UNKNOWN);
    }

    // client init:
    //     + unknown -> client: lấy theo trading map cũ rồi update theo trạng thái hiện tại
    //     + client  -> client: lấy theo trading map cũ rồi update theo trạng thái hiện tại
    //     + server  -> client:
    //         1, nếu dữ liệu cũ còn position đang chạy ->  close EA
    //         2, case khác: update session theo trạng thái hiện tại (ko lấy dữ liệu cũ)
    bool Init(CPT_InOutManager* inOutController) override
    {
        CPT_LocalTerminal::Init(inOutController);
        m_pInOutManager.InitFilesPath();

        // 1: load previous session và kiểm tra
        CPT_CopyTradeSession previousSession();
        previousSession.LoadPreviousSession();

        iPosition posArr[];
        TerminalAPI::DoGetAllPosition(posArr);
        ulong closedPosition[];
        ulong newPosition[];
        previousSession.Compare(posArr, newPosition, closedPosition);
        int currentPosNum = ArraySize(posArr);
        int closedPosNum  = ArraySize(closedPosition);
        int newPosNum     = ArraySize(newPosition);
        LOGD("previous mode=" + ToString(previousSession.GetMode()) + " preWeight=" + (string)previousSession.GetWeight() + "nowWeight=" + (string)mSession.GetWeight());
        LOGD("currentPosNum=" + (string)currentPosNum + " closedPosNum=" + (string)closedPosNum + " newPosNum=" + (string)newPosNum);

        bool res = true;
        int i = 0, j = 0;
        // unknown -> client:
        // client  -> client:
        //          lấy theo trading map cũ rồi update theo trạng thái hiện tại
        if (previousSession.GetMode() == eCPT_MODE_UNKNOWN
            || previousSession.GetMode() == eCPT_MODE_CLIENT)
        {
            mSession.SetSessionId(previousSession.GetSessionId());
            previousSession.CopyTradingMap(mSession);
            mSession.UpdateLatestPosition(posArr);
        }
        // server  -> client: 
        //      update session theo trạng thái hiện tại (ko lấy dữ liệu cũ)
        //      nếu còn position đang chạy thì warning cho user
        else if (previousSession.GetMode() == eCPT_MODE_SERVER)
        {
            if (currentPosNum > 0)
            {
                TerminalAPI::DoShowMessagePopup("SERVER -> CLIENT: some Positions are existed!!! be carefull!!!");
            }
            mSession.UpdateLatestPosition(posArr);
        }
        else
        {
            TerminalAPI::DoShowMessagePopup("ERROR init CLIENT: invalid previous Mode");
            res = false;
        }
        if (res == true)
        {
            SetConnectionState(eSERVER_CONN_STATE_DISCONNECTED);
        }
        return res;
    }

    void Terminate() override
    {
        LOGD("terminate ClientTerminal...");
        int copyTradePosNum = mSession.GetCptPositionNumber();
        mSession.SaveSession();

        if (mBuyStrategy)
        {
            delete mBuyStrategy;
        }
        if (mSellStrategy)
        {
            delete mSellStrategy;
        }
    }

    /**********************************************************************************
    *
    *   Copytrade with reverted position:
    *       sell -> buy
    *       buy  -> sell
    *
    ***********************************************************************************/
private:
    bool mIsRevertPositionEnable;
    double mStoplostThreshold;
    double mTakeProfitThreshold;
    CPT_Strategy *mBuyStrategy;
    CPT_Strategy *mSellStrategy;

    void Rp_OnPositionAdded(const iPosition& newPos)
    {
        switch(newPos.position_type)
        {
            case ePOSITION_TYPE_BUY: { 
                mBuyStrategy.OnNewPositionAdded(newPos);
                break;
            }
            case ePOSITION_TYPE_SELL: {
                mSellStrategy.OnNewPositionAdded(newPos);
                break;
            }
            default:
                LOGE("Error position_type");
                break;
        }
    }
    void Rp_OnPositionClosed(const iPosition& closedPos)
    {
        switch(closedPos.position_type)
        {
            case ePOSITION_TYPE_BUY: { 
                mBuyStrategy.OnPositionClose(closedPos);
                break;
            }
            case ePOSITION_TYPE_SELL: {
                mSellStrategy.OnPositionClose(closedPos);
                break;
            }
            default:
                LOGE("Error position_type");
                break;
        }
    }

public:
    void SetRpEnable(bool isEnable) override
    {
        mIsRevertPositionEnable = isEnable;
        LOGD("mIsRevertPositionEnable=" + (string)mIsRevertPositionEnable);
    }

    void SetRpThresholds(double slThreshold, double tpThreshold) override
    {
        mStoplostThreshold = slThreshold;
        mTakeProfitThreshold = tpThreshold;
        LOGD("mStoplostThreshold=" + (string)mStoplostThreshold + " mTakeProfitThreshold=" + (string)mTakeProfitThreshold);
    }

    void SetRpPlan(int rp_plan) override
    {
        LOGD("rp_plan=" + (string)rp_plan);
        mBuyStrategy = CPT_Strategy_Factory::MakeStrategy(rp_plan, ePOSITION_TYPE_BUY);
        mSellStrategy = CPT_Strategy_Factory::MakeStrategy(rp_plan, ePOSITION_TYPE_SELL);
    }

    void OnTimer() override
    {
        double cur_price = 0.0;

        if (mBuyStrategy)
        {
            cur_price = TerminalAPI::GetCurrentPrice(_Symbol, true);
            mBuyStrategy.OnPriceUpdate(cur_price);
        }
        if (mSellStrategy)
        {
            cur_price = TerminalAPI::GetCurrentPrice(_Symbol, false);
            mSellStrategy.OnPriceUpdate(cur_price);
        }
    }

    /**********************************************************************************
    *
    *   Possions changed
    *
    ***********************************************************************************/
    void OnPositionAdded(const iPosition& newPos) override
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
                if (mIsRevertPositionEnable)
                {
                    Rp_OnPositionAdded(newPos);
                }
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

    void OnPositionClosed(const iPosition& closedPos) override
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
        if (mIsRevertPositionEnable)
        {
            Rp_OnPositionClosed(closedPos);
        }
    }

    /**********************************************************************************
    *
    *  quản lý connection với server
    *
    ***********************************************************************************/
private:
    enum EnumServerConnectionState
    {
        eSERVER_CONN_STATE_UNKNOWN,                 // state ban đầu
        eSERVER_CONN_STATE_DISCONNECTED,            // state mà connected chuyển về nếu detect mất file
        eSERVER_CONN_STATE_CONNECTING,              // phát hiện file -> bắt đầu kết nối
        eSERVER_CONN_STATE_CONNECTED                // trao đổi thông tin
    };
    EnumServerConnectionState m_state;
    static string StateToString(EnumServerConnectionState state)
    {
        switch (state)
        {
            case eSERVER_CONN_STATE_DISCONNECTED: return "DISCONNECTED";
            case eSERVER_CONN_STATE_CONNECTING: return "CONNECTING";
            case eSERVER_CONN_STATE_CONNECTED: return "CONNECTED";
            default:
                return "UNKNOWN";
        }
    }
    void SetConnectionState(EnumServerConnectionState newState)
    {
        if (m_state != newState)
        {
            m_state = newState;
            LOGD("Connection state change: " + (string)StateToString(m_state));
        }
    }

    /**********************************************************************************
    *
    *  polling data and switch state
    *  và các hàm xử lý khi chuyển state
    *
    ***********************************************************************************/
private:
    /*
    *   khi server bị tắt đột ngội thì client remove các file output đi.
    *   để khi server lên lại, thì quá trình connect sẽ dc chạy lại
    */
    void Connected_OnServerDisconnection()
    {
        m_pInOutManager.Terminate();
        SetConnectionState(eSERVER_CONN_STATE_DISCONNECTED);
    }

    /*
    *   detect ra input file của server dc tạo
    *       + Seek to end of inputfile để đảm bảo chỉ đọc các cmd từ lúc kết nối
    *       + bắt đầu tạo input file của mình.
    */
    void Disconnected_OnServerInputFileDetected()
    {
        LOGD("SERVER File is detected.");
        m_pInOutManager.SeekToEndInputFile();
        m_pInOutManager.Init();
        SetConnectionState(eSERVER_CONN_STATE_CONNECTING);
    }
    
    /*
    *   mất kết nối server trong quá trính connecting\ -> action tương tự disconnect trong connected
    */
    void Connecting_OnServerDisconnection()
    {
        m_pInOutManager.Terminate();
        SetConnectionState(eSERVER_CONN_STATE_DISCONNECTED);
    }

    /*
    *   thực hiện update data theo server
    */
    void Connecting_OnServerUpdate(int server_sessionId, string serverSymbol, iPosition &server_positions[], iPosition &now_client_positions[])
    {
        int server_posNum = ArraySize(server_positions);
        int now_client_posNum = ArraySize(now_client_positions);
        LOGD("CMD-UPDATE detected: remote-session:" + (string)server_sessionId + " symbol:" + serverSymbol + " server-posnum:" + (string)server_posNum);
        LOGD("my-session:" +(string)mSession.GetSessionId() + " symbol:" + _Symbol + " client-posnum:" + (string)now_client_posNum);

        //*********************************************************************************
        // check the Symbol first
        //*********************************************************************************
        EnumSymbolType serverSymbolType = CheckSymbolType(serverSymbol);
        EnumSymbolType localSymbolType = CheckSymbolType(_Symbol);
        if (serverSymbolType != localSymbolType)
        {
            TerminalAPI::DoShowMessagePopup("ERROR: please attach to exact chart same as server!!!");
            TerminalAPI::DoCloseEA();
            return;
        }

        int i = 0, j = 0;
        bool isExisted = false;
        //*********************************************************************************
        // A, xác định session-id
        //      + Luôn luôn lấy session-id theo server
        //      + nếu session khác server-id, 
        //*********************************************************************************
        if (mSession.GetSessionId() != 0 && server_sessionId != mSession.GetSessionId())
        {
            LOGD("Difference session-id, server:" + (string)server_sessionId + " client:" + (string)mSession.GetSessionId());
        } 
        mSession.SetSessionId(server_sessionId);

        //*********************************************************************************
        // B, update thông tin session theo thực trạng của server
        //      1, server new position: add [ticket, 0]
        //      2, server closed positon: check nếu tồn tại trong sesison
        //              2.1, position chưa close -> thực hiện close position
        //              2.2, position đã close   -> remove khỏi session
        //*********************************************************************************
        // 1, server new position: add [ticket, 0]
        for (i = 0; i < server_posNum; i++)
        {
            if (mSession.HasServerTicket(server_positions[i].position_ticket) == false)
            {
                mSession.AddCopyTradePosition(server_positions[i].position_ticket, 0);
            }
        }
        
        // 2, check server closed positon:
        //      2.1 tìm tất cả các ticket mà đã bị close
        //      2.2 thực hiện close bên client nếu ticket-positon đối ứng vẫn tồn tại
        //          remove trong mSession nếu ticket đối ứng ko tồn tại
        ulong tradingMap[];
        mSession.GetTradingData(tradingMap);
        int tradingMapSize = ArraySize(tradingMap);
        // 2.1
        ulong server_closedTickets[];
        ArrayResize(server_closedTickets, tradingMapSize/2);
        int closedTicketsCount = 0;
        for (i = 0; i < tradingMapSize; i += 2)
        {
            if (tradingMap[i] != 0)
            {
                isExisted = false;
                for (j = 0; j < server_posNum; j++)
                {
                    if (tradingMap[i] == server_positions[j].position_ticket)
                    {
                        isExisted = true; break;
                    }
                }
                if (isExisted == false)
                {
                    server_closedTickets[closedTicketsCount] = tradingMap[i];
                    closedTicketsCount += 1;
                }
            }
        }
        // 2.2
        LOGD("server has " + (string)closedTicketsCount + " positions closed.");
        for (i = 0; i < closedTicketsCount; i++)
        {
            ulong server_ticket = server_closedTickets[i];
            ulong client_ticket = mSession.GetClientTicket(server_ticket);
            
            isExisted = false;
            for (j = 0; j < now_client_posNum; j++)
            {
                if (client_ticket == now_client_positions[j].position_ticket)
                {
                    isExisted = true; break;
                }
            }
            if (isExisted == true)
            {
                LOGD("Process closed position [" + (string)server_ticket + ", " + (string)client_ticket + "]");
                CopyTradeReqData evData = {0};
                evData.server_ticket = server_ticket;
                evData.volume = now_client_positions[j].volume;
                evData.position_type = now_client_positions[j].position_type;
                evData.target_ticket = client_ticket;
                Event ev = ObtainEvent(EV_CLOSED_POSITION);
                EventUtils::ToData(ev, evData);
                SendEvent(ev);
            }
            else
            {
                mSession.RemoveCopyTradePosition(server_closedTickets[i], client_ticket);
            }
        }

        //*********************************************************************************
        // C, update state và logging
        //*********************************************************************************
        mSession.Logging();
        SetConnectionState(eSERVER_CONN_STATE_CONNECTED);
    }

    /**********************************************************************************
    *
    *  Polling function: đọc file input và chuyển tới hàm xử lý tương ứng
    *
    ***********************************************************************************/
public:
    void DoPoll() override
    {
        // bắt đầu polling data
        bool isInputExisted = m_pInOutManager.CheckInputFile();
        string cmdList[];
        int cmdNum = 0;
        switch (m_state)
        {
            case eSERVER_CONN_STATE_DISCONNECTED:
            {
                if (isInputExisted == true)
                {
                    Disconnected_OnServerInputFileDetected();
                }
                break;
            }
            case eSERVER_CONN_STATE_CONNECTING:
            {
                if (isInputExisted == false)
                {
                    Connecting_OnServerDisconnection();
                }
                else
                {
                    cmdNum = m_pInOutManager.PollData(cmdList);
                    if (cmdNum > 0)
                    {
                        Connecting_HandleServerCommands(cmdList);
                    }
                }
                break;
            }
            case eSERVER_CONN_STATE_CONNECTED:
            {
                // đang connected, ko tìm thấy input file
                if (isInputExisted == false)
                {
                    Connected_OnServerDisconnection();
                }
                // đọc cmds khi kết nối vẫn connected
                else
                {
                    cmdNum = m_pInOutManager.PollData(cmdList);
                    if (cmdNum > 0)
                    {
                        Connected_HandleServerCommands(cmdList);
                    }
                }
                break;
            }
            default:
                break;
        }
    }

    /**********************************************************************************
    *
    *  các hàm xử lý command
    *
    ***********************************************************************************/
private:
    void Connecting_HandleServerCommands(string &cmdList[])
    {
        // tìm bản tin update mà server gửi cho chính xác client-id
        // bỏ qua những cmd khác.
        int cmdListSize = ArraySize(cmdList);
        for(int cmd_idx = 0; cmd_idx < cmdListSize; cmd_idx++)
        {
            string cmdStr = cmdList[cmd_idx];
            int cmd = ParseIntValue(cmdStr, "cmd");
            // ignore các cmd trong  state connecting
            if (cmd != eCMD_CPT_UPDATE)
            {
                continue;
            }
            // chỉ nhận thông tin của server gửi cho client với id chính xác.
            int client_id =  ParseIntValue(cmdStr, "to_client");
            if (client_id == m_pInOutManager.GetId())
            {
                string PositonArrayStr = ParseJsonValue(cmdStr, "curr_positions");
                string tradeSymbol = ParseJsonValue(cmdStr, "trade_symbol");
                int server_sessionId = ParseIntValue(cmdStr, "session_id");

                iPosition server_positions[];
                ParseJsonArrayToPositions(PositonArrayStr, server_positions);

                iPosition now_client_positions[];
                TerminalAPI::DoGetAllPosition(now_client_positions);

                Connecting_OnServerUpdate(server_sessionId, tradeSymbol, server_positions, now_client_positions);

                // chuyển cmd còn lại sang Connected_HandleServerCommands
                string remain_cmds[];
                ArrayResize(remain_cmds, cmdListSize - cmd_idx - 1);
                for (int i = cmd_idx + 1; i < cmdListSize; i++)
                {
                    remain_cmds[i - cmd_idx - 1] = cmdList[i];
                }
                Connected_HandleServerCommands(remain_cmds);
                break;
            }
        }
    }

    void Connected_HandleServerCommands(string &cmdList[])
    {
        int size = ArraySize(cmdList);
        string PositonJsonStr = "";
        int serverSession = 0;
        for(int i = 0; i < size; i++)
        {
            string cmdStr = cmdList[i];
            int cmd = ParseIntValue(cmdStr, "cmd");
            switch (cmd)
            {
                case eCMD_CPT_UPDATE:
                {
                    break;
                }
                case eCMD_CPT_POS_ADDED:
                {
                    PositonJsonStr = ParseJsonValue(cmdStr, "position_info");
                    iPosition newPos = ParseJsonToPosition(PositonJsonStr);
                    serverSession = ParseIntValue(cmdStr, "session_id");
                    OnServer_NewPositionAdded(serverSession, newPos);
                    break;
                }
                case eCMD_CPT_POS_CLOSED:
                {
                    PositonJsonStr = ParseJsonValue(cmdStr, "position_info");
                    iPosition closedPos = ParseJsonToPosition(PositonJsonStr);
                    serverSession = ParseIntValue(cmdStr, "session_id");
                    OnServer_PositionClosed(serverSession, closedPos); 
                    break;
                }
                default:
                    // ignore các cmd khác
                    break;
            }
        }
    }

    void OnServer_NewPositionAdded(int session, iPosition &newPos)
    {
        LOGD(">>> " + (string)session + " " + ToString(newPos));
        if (session != mSession.GetSessionId())
        {
            LOGE("ERROR: server-session: " + (string)session + " my-session: " + (string)mSession.GetSessionId());
            return;
        }
        if (mSession.HasServerTicket(newPos.position_ticket))
        {
            LOGE("server-ticket is already in the trading map: " + (string)newPos.position_ticket);
            return;
        }

        CopyTradeReqData reqData = {0};
        reqData.server_ticket = newPos.position_ticket;
        if (mIsRevertPositionEnable == true)
        {
            if (newPos.position_type == ePOSITION_TYPE_BUY)
            {
                reqData.position_type = ePOSITION_TYPE_SELL;
                reqData.volume = mSellStrategy.GetNextVolume(newPos.volume, mSession.GetWeight());
            }
            else if (newPos.position_type == ePOSITION_TYPE_SELL)
            {
                reqData.position_type = ePOSITION_TYPE_BUY;
                reqData.volume = mBuyStrategy.GetNextVolume(newPos.volume, mSession.GetWeight());
            }
            else
            {
                LOGE("Unknown position type from server!!!");
            }
        }
        else
        {
            reqData.position_type = newPos.position_type;
            reqData.volume = TradeUtils::NormalizeVolume(_Symbol, newPos.volume * mSession.GetWeight());
        }
        Event ev = ObtainEvent(EV_ADD_NEW_POSITION);
        EventUtils::ToData(ev, reqData);
        SendEvent(ev);
    }

    void OnServer_PositionClosed(int session, iPosition &closedPos)
    {
        LOGD(">>> " + (string)session + " " + ToString(closedPos));
        if (session != mSession.GetSessionId())
        {
            LOGE("ERROR: server-session: " + (string)session + " my-session: " + (string)mSession.GetSessionId());
            return;
        }
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
                        LOGD("the target has not done placing position, server-ticket" + (string)closedPos.position_ticket);
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
                        LOGD("ignore close pos for server-ticket[" + (string)closedPos.position_ticket + "] state=" + (string)pendingEv.state);
                    }
                    break;
                }
            }

            // trường hợp ko tìm thấy trong pendingList thì có thể đặt lệnh failed
            // thử remove trong session
            if (hasPendingAddNewPosEvent == false)
            {
                LOGD("the target not found, server-ticket" + (string)closedPos.position_ticket);
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