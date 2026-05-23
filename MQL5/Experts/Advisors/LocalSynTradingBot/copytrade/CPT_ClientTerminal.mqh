#include "../common/Types.mqh"
#include "CPT_LocalTerminal.mqh"
#include "CPT_CopyTradeSession.mqh"

class CPT_ClientTerminal : public CPT_LocalTerminal
{
private:
    CPT_CopyTradeSession mSession;

    /**********************************************************************************
    *
    *   Event Queue
    *   queue xử lý copy trade event và các hàm quản lý queue
    *
    ***********************************************************************************/
    enum EnumCopyTradeEvent
    {
        EV_ADD_NEW_POSITION = 1,
        EV_CLOSED_POSITION = 2,
        EV_CLOSED_POSITION_WHEN_ADDPOS_NOT_DONE = 3,
    };
    CopyTradeEvent mCopyTradeEventQueue[];

    bool HandleEvent(CopyTradeEvent& ev)
    {
        if(ev.status != EVS_QUEUED)
        {
            LOGE("Event is in wrong state " + ToString(ev));
            return false;
        }
        bool res = false;
        switch (ev.eventId)
        {
            case EV_ADD_NEW_POSITION:
            {
                LOGD("execute EV_ADD_NEW_POSITION");
                res = TerminalAPI::DoCopyTrade_OpendPosition(ev);
                break;
            }
            case EV_CLOSED_POSITION:
            {
                LOGD("execute EV_CLOSED_POSITION");
                res = TerminalAPI::DoCopyTrade_ClosePosition(ev);
                break;
            }
            case EV_CLOSED_POSITION_WHEN_ADDPOS_NOT_DONE:
            {
                LOGD("execute EV_CLOSED_POSITION_WHEN_ADDPOS_NOT_DONE");
                ulong target_ticket = mSession.GetClientTicket(ev.server_ticket);
                if (target_ticket != 0)
                {
                    LOGD("switch EV_CLOSED_POSITION_WHEN_ADDPOS_NOT_DONE->EV_CLOSED_POSITION: target=" + (string)target_ticket);
                    ev.eventId = EV_CLOSED_POSITION;
                    ev.target_ticket = target_ticket;
                    res = TerminalAPI::DoCopyTrade_ClosePosition(ev);
                }
                else
                {
                    LOGD("seem to be add new event failed, drop CLOSE event. sv-ticket:" + (string)ev.server_ticket);
                    ev.status = EVS_DROP;
                }
                break;
            }
            default:
                LOGE("ERROR event id=" + (string)ev.eventId);
                ev.status = EVS_DROP; // gán EVS_DROP để ignore event và next cái mới
                break;
        }
        return res;
    }

    void HandleEventDone(CopyTradeEvent& ev)
    {
        if(ev.status != EVS_DONE)
        {
            LOGE("Event is in wrong state " + ToString(ev));
            return;
        }
        switch (ev.eventId)
        {
            case EV_ADD_NEW_POSITION:
            {
                LOGD("ADD_NEW_POSITION done: server:" + (string)ev.server_ticket + " client:" + (string)ev.target_ticket);
                mSession.AddCopyTradPosition(ev.server_ticket, ev.target_ticket);
                break;
            }
            case EV_CLOSED_POSITION:
            {
                LOGD("CLOSED_POSITION done: client:" + (string)ev.target_ticket);
                mSession.RemoveCopyTradePosition(ev.server_ticket, ev.target_ticket);
                break;
            }
            case EV_CLOSED_POSITION_WHEN_ADDPOS_NOT_DONE:
            {
                LOGD("EV_CLOSED_POSITION_WHEN_ADDPOS_NOT_DONE done");
                break;
            }
            default:
                LOGE("ERROR event id=" + (string)ev.eventId);
                break;
        }
    }

    void Execute()
    {
        if (ArraySize(mCopyTradeEventQueue) == 0)
        {
            return;
        }

        // xử lý event:
        //      + nếu event xử lý ok -> chuyển state PROCESSING
        //      + nếu evnet xử lý failse -> chuyển state FAILED để retry hoặc next ev khác nếu nó bị DROP
        if (mCopyTradeEventQueue[0].status == EVS_QUEUED)
        {
            bool res = HandleEvent(mCopyTradeEventQueue[0]);
            if (res) {
                mCopyTradeEventQueue[0].status = EVS_PROCESSING;
                mCopyTradeEventQueue[0].time_out = 0;
            }
            else
            {
                if (mCopyTradeEventQueue[0].status == EVS_DROP) {
                    // do nothing
                } else {
                    mCopyTradeEventQueue[0].status = EVS_FAILED;
                }
            }
            Execute();
        }
        // check timeout
        else if (mCopyTradeEventQueue[0].status == EVS_PROCESSING)
        {
            const int TIME_OUT = 5;
            // chờ timeout 3s
            if (mCopyTradeEventQueue[0].time_out < TIME_OUT)
            {
                mCopyTradeEventQueue[0].time_out++;
            }
            // timeout -> set state failed.
            else
            {
                mCopyTradeEventQueue[0].status = EVS_FAILED;
                Execute();
            }
        }
        // retry
        else if (mCopyTradeEventQueue[0].status == EVS_FAILED)
        {
            const int MAX_RETRY = 3;
            if (mCopyTradeEventQueue[0].retry_count < MAX_RETRY)
            {
                mCopyTradeEventQueue[0].retry_count++;
                mCopyTradeEventQueue[0].status = EVS_QUEUED;
            }
            else
            {
                mCopyTradeEventQueue[0].status = EVS_DROP;
                if (mCopyTradeEventQueue[0].eventId == EV_ADD_NEW_POSITION)
                {
                    mSession.AddCopyTradPosition(mCopyTradeEventQueue[0].server_ticket, 0);
                }
            }
            Execute();
        }
        // update session sau đó pop event
        else if (mCopyTradeEventQueue[0].status == EVS_DONE)
        {
            HandleEventDone(mCopyTradeEventQueue[0]);
            PopCopyTradeEvent();
        }
        // pop event
        else if (mCopyTradeEventQueue[0].status == EVS_DROP)
        {
            PopCopyTradeEvent();
        }
        else
        {
            LOGE("ERROR: wrong event state: " + (string)mCopyTradeEventQueue[0].status);
        }
    }

    void AddCopytradeEvent(CopyTradeEvent &ev)
    {
        int size = ArraySize(mCopyTradeEventQueue);
        ArrayResize(mCopyTradeEventQueue, size + 1);
        mCopyTradeEventQueue[size] = ev;
        mCopyTradeEventQueue[size].status = EVS_QUEUED;
        LOGD("event=" + ToString(ev));
        if (size == 0)
        {
            Execute();
        }
    }

    void PopCopyTradeEvent()
    {
        int size = ArraySize(mCopyTradeEventQueue);
        if(size > 0)
        {
            for(int i = 1; i < size; i++)
            {
                mCopyTradeEventQueue[i - 1] = mCopyTradeEventQueue[i];
            }

            ArrayResize(mCopyTradeEventQueue, size - 1);
            if (size - 1 > 0)
            {
                Execute();
            }
        }
    }

    bool HasPendingEvent(int event_id, ulong server_ticket)
    {
        int size = ArraySize(mCopyTradeEventQueue);
        for (int i = 0; i < size; i++)
        {
            if (mCopyTradeEventQueue[i].eventId == event_id &&
                mCopyTradeEventQueue[i].server_ticket == server_ticket)
            {
                return true;
            }
        }
        return false;
    }

    bool TryIgnoreEvent(int event_id, ulong server_ticket)
    {
        int size = ArraySize(mCopyTradeEventQueue);
        for (int i = 1; i < size; i++)
        {
            if (mCopyTradeEventQueue[i].eventId == event_id &&
                mCopyTradeEventQueue[i].server_ticket == server_ticket && 
                mCopyTradeEventQueue[i].status == EVS_QUEUED)
            {
                mCopyTradeEventQueue[i].status = EVS_DROP;
                return true;
            }
        }
        return false;
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
        //     1, nếu dữ liệu cũ còn position đang chạy ->  close EA
        //     2, case khác: update session theo trạng thái hiện tại (ko lấy dữ liệu cũ)
        else if (previousSession.GetMode() == eCPT_MODE_SERVER)
        {
            ulong oldMap[];
            previousSession.GetTradingData(oldMap);
            int tradingDataSize = ArraySize(oldMap);
            bool isOldTradeIsExisted = false;
            for (i = 0; i < tradingDataSize; i += 2)
            {
                for  (j = 0; j < currentPosNum; j ++)
                {
                    if (oldMap[i] != 0 && oldMap[i + 1] != 0 && oldMap[i + 1] == posArr[j].position_ticket)
                    {
                        isOldTradeIsExisted = true;
                        break;
                    }
                }
                if (isOldTradeIsExisted) break;
            }
            if (isOldTradeIsExisted)
            {
                TerminalAPI::DoShowMessagePopup("ERROR init SERVER -> CLIENT: CPT Positions existed!!! please check!!!");
                res = false;
            }
            else
            {
                mSession.UpdateLatestPosition(posArr);
            }
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

        // check event queue: logging out
        int size = ArraySize(mCopyTradeEventQueue);
        for (int i = 0; i < size; i++)
        {
            LOGD("Event Queue is not Emplty: " + ToString(mCopyTradeEventQueue[i]));
        }
    }

    /**********************************************************************************
    *
    *   Possions changed
    *
    ***********************************************************************************/
    void OnPositionAdded(iPosition& newPos) override
    {
        int queue_size = ArraySize(mCopyTradeEventQueue);

        // sau khi position added: cần check lại và update event thành DONE
        bool isCopyTradePositionAdded = false;
        if (queue_size > 0 && mCopyTradeEventQueue[0].eventId == EV_ADD_NEW_POSITION)
        {
            if (mCopyTradeEventQueue[0].tracking_number == newPos.magic_number)
            {
                isCopyTradePositionAdded = true;
                mCopyTradeEventQueue[0].status = EVS_DONE;
                mCopyTradeEventQueue[0].target_ticket = newPos.position_ticket;
            }
        }

        // nếu ko phải postion cho copy trade, thì add nó ở dạng [0, pos-id]
        if (isCopyTradePositionAdded == false)
        {
            mSession.AddCopyTradPosition(0, newPos.position_ticket);
        }
    }

    void OnPositionClosed(iPosition& closedPos) override
    {
        int queue_size = ArraySize(mCopyTradeEventQueue);

        bool isCopyTradePositionClosed = false;
        if (queue_size > 0)
        {
            // sau khi position closed, cần check lại và update event thành DONE
            if (mCopyTradeEventQueue[0].eventId == EV_CLOSED_POSITION &&
                mCopyTradeEventQueue[0].target_ticket == closedPos.position_ticket)
            {
                isCopyTradePositionClosed = true;
                mCopyTradeEventQueue[0].status = EVS_DONE;
            }
            // set EVS_DROP cho queue-event khi ticket là target-ticket và event chưa dc process
            else
            {
                for (int i = 1; i < queue_size; i++)
                {
                    if (mCopyTradeEventQueue[i].eventId == EV_CLOSED_POSITION &&
                        mCopyTradeEventQueue[i].target_ticket == closedPos.position_ticket)
                    {
                        LOGD("DROP queue-event because target-ticket(" + (string)closedPos.position_ticket
                                + ") is closed before the event is processed ");
                        mCopyTradeEventQueue[i].status = EVS_DROP;
                        break;
                    }
                }
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
    void Connecting_OnServerUpdate(int server_sessionId, iPosition &server_positions[], iPosition &now_client_positions[])
    {
        int server_posNum = ArraySize(server_positions);
        int now_client_posNum = ArraySize(now_client_positions);
        int pre_client_posNum = mSession.GetClientPositionNumer();
        LOGD("CMD-UPDATE detected: remote-session:" + (string)server_sessionId + 
                                    " my-session:" +(string)mSession.GetSessionId() + 
                                    " server-posnum:" + (string)server_posNum +
                                    " client-posnum:" + (string)now_client_posNum +
                                    " pre-client-posnum:" + (string)pre_client_posNum);

        //*********************************************************************************
        // A, xác định session-id
        //     1, client-session = 0: lấy theo server-session
        //     2, client-session == server-session: giữ nguyên ssid
        //     3, client-session != server-session:
        //          + nếu client ko có position nào: lấy server-session
        //          + nếu client có position -> noti ERRIRO, close EA
        //*********************************************************************************
        // 1, client-session = 0:
        if (mSession.GetSessionId() == 0)
        {
            mSession.SetSessionId(server_sessionId);
        }
        // 2, client-session == server-sesion:
        else if (server_sessionId == mSession.GetSessionId())
        {
            // keep current ssid
        }
        // 3, client-session != server-sesion:
        else //if (server_sessionId != mSession.GetSessionId())
        {
            if (now_client_posNum > 0)
            {
                TerminalAPI::DoShowMessagePopup("ERROR in CLIENT connecting: missmatch session id and positions existed has not closed!! please check!!!");
                TerminalAPI::DoCloseEA();
                return;
            }
            else
            {
                mSession.SetSessionId(server_sessionId);
            }
        }

        //*********************************************************************************
        // B, update thông tin session theo thực trạng
        //      1, lấy now-position update vào mSession: [0, posid]
        //      2, lấy server-position update vào mSession: [sever-posid, 0]
        //*********************************************************************************
        ulong tradingMap[];
        mSession.GetTradingData(tradingMap);
        int tradingMapSize = ArraySize(tradingMap);

        // 1, remove những pair ko còn tồn tại
        int i = 0, j = 0;
        bool isExisted = false;
        for (i = 0; i < tradingMapSize; i += 2)
        {
            isExisted = false;
            // check tồn tại trong server_positions ko?
            if (tradingMap[i] != 0)
            {
                for (j = 0; j < server_posNum; j++) {
                    if (server_positions[j].position_ticket == tradingMap[i]) { isExisted = true; break; }
                }
            }
            // check tồn tại trong now_client_positions ko?
            if (isExisted && tradingMap[i + 1] != 0)
            {
                for (j = 0; j < now_client_posNum; j++) {
                    if (now_client_positions[j].position_ticket == tradingMap[i + 1]) { isExisted = true; break; }
                }
            }
            if (!isExisted)
            {
                mSession.RemoveCopyTradePosition(tradingMap[i], tradingMap[i + 1]);
            }
        }

        // 2, lấy now-position update vào mSession: [0, posid]
        for (i = 0; i < now_client_posNum; i++)
        {
            if (mSession.HasClientTicket(now_client_positions[i].position_ticket) == false)
            {
                mSession.AddCopyTradPosition(0, now_client_positions[i].position_ticket);
            }
        }

        // 3, lấy server-position update vào mSession: [sever-posid, 0]
        for (i = 0; i < server_posNum; i++)
        {
            if (mSession.HasServerTicket(server_positions[i].position_ticket) == false)
            {
                mSession.AddCopyTradPosition(server_positions[i].position_ticket, 0);
            }
        }

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
        // execute events trước khi thực hiện polling data
        Execute();

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
                int server_sessionId = ParseIntValue(cmdStr, "session_id");

                iPosition server_positions[];
                ParseJsonArrayToPositions(PositonArrayStr, server_positions);

                iPosition now_client_positions[];
                TerminalAPI::DoGetAllPosition(now_client_positions);

                Connecting_OnServerUpdate(server_sessionId, server_positions, now_client_positions);

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

    double NormalizeVolume(string symbol, double volume)
    {
        double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double step   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

        volume = MathMax(minLot, MathMin(maxLot, volume));

        volume = MathRound(volume / step) * step;

        int digits = (int)MathRound(-MathLog10(step));

        return NormalizeDouble(volume, digits);
    }

    void OnServer_NewPositionAdded(int session, iPosition &newPos)
    {
        LOGD("session: " + (string)session + " " + ToString(newPos));
        if (session != mSession.GetSessionId())
        {
            LOGE("ERROR: server-session: " + (string)session + " my-session: " + (string)mSession.GetSessionId());
            return;
        }
        CopyTradeEvent ev = {0};
        ev.eventId = EV_ADD_NEW_POSITION;
        ev.server_ticket = newPos.position_ticket;
        ev.position_type = newPos.position_type;
        ev.volume = NormalizeVolume(_Symbol, newPos.volume * mSession.GetWeight());
        AddCopytradeEvent(ev);
    }

    void OnServer_PositionClosed(int session, iPosition &closedPos)
    {
        LOGD("session: " + (string)session + " " + ToString(closedPos));
        if (session != mSession.GetSessionId())
        {
            LOGE("ERROR: server-session: " + (string)session + " my-session: " + (string)mSession.GetSessionId());
            return;
        }
        ulong target_ticket = mSession.GetClientTicket(closedPos.position_ticket);
        if (target_ticket == 0)
        {
            // trong trường hợp event add new position chưa xong,
            // nếu server close positon đó, thì sẽ ko thể tìm thấy target position
            if (HasPendingEvent(EV_ADD_NEW_POSITION, closedPos.position_ticket) == true)
            {
                LOGD("the target has not done placing position, server-ticket" + (string)closedPos.position_ticket);
                if (TryIgnoreEvent(EV_ADD_NEW_POSITION, closedPos.position_ticket) == true)
                {
                    LOGD("ignored the ADD event: sv-ticket:" + (string)closedPos.position_ticket);
                }
                else
                {
                    CopyTradeEvent ev = {0};
                    ev.eventId = EV_CLOSED_POSITION_WHEN_ADDPOS_NOT_DONE;
                    ev.server_ticket = closedPos.position_ticket;
                    ev.volume = NormalizeVolume(_Symbol, closedPos.volume * mSession.GetWeight());
                    ev.position_type = closedPos.position_type;
                    AddCopytradeEvent(ev);
                }
            }
            else
            {
                LOGD("can not find the target, server-ticket:" + (string)closedPos.position_ticket);
                // thử remove data trong session
                mSession.RemoveCopyTradePosition(closedPos.position_ticket, 0);
            }
            return;
        }
        CopyTradeEvent ev = {0};
        ev.eventId = EV_CLOSED_POSITION;
        ev.server_ticket = closedPos.position_ticket;
        ev.volume = NormalizeVolume(_Symbol, closedPos.volume * mSession.GetWeight());
        ev.position_type = closedPos.position_type;
        ev.target_ticket = target_ticket;
        AddCopytradeEvent(ev);
    }
};