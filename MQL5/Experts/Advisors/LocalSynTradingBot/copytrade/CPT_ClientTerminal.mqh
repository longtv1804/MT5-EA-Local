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
        EV_CLOSED_POSITION = 2
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
                mSession.RemoveCopyTradePosition(ev.target_ticket);
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
                if (mCopyTradeEventQueue[0].status == EVS_DROP){
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

    /**********************************************************************************
    *
    *   init/terminate
    *
    *
    ***********************************************************************************/
public:
    CPT_ClientTerminal(double weight) 
    :   CPT_LocalTerminal(),
        mSession(eCPT_MODE_SERVER, 0, weight) 
    {
        m_state = eSERVER_CONN_STATE_UNKNOWN;
    }

    /*
    *   init client:
    *   + thực hiện load session info trước đó
    *   + thực hiện kiểm tra:
    *       1, client -> client: chỉ init khi ko có pos nào đang chạy hoặc các pos đều thuộc session cũ.
    *       2, server -> client: chỉ init khi ko có pos nào.
    *       3, unkown -> client: chỉ init khi ko có pos nào.
    */
    bool Init(CPT_InOutManager* inOutController) override
    {
        CPT_LocalTerminal::Init(inOutController);

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
        LOGD("previous mode=" + ToString(previousSession.GetMode()) + 
                                " previousWeight=" + (string)previousSession.GetWeight() +
                                " currentWeight=" + (string)mSession.GetWeight() +
                                " currentPosNum=" + (string)currentPosNum + 
                                " closedPosNum=" + (string)closedPosNum + 
                                " newPosNum=" + (string)newPosNum);
        bool res = true;
        int i =0, j = 0;
        //client  -> client:
        //	1, ko có position nào: chờ connecting
        //	2, possion list trùng hoàn toàn với session cũ: lấy session cũ
        //	3, possion list trùng một phần (có cái bị close, có new pos): lấy session cũ
        //	4, possion cũ bị close hết
        //	5, case khác: close EA 
        if (previousSession.GetMode() == eCPT_MODE_CLIENT)
        {
            //	1, ko có position nào: chờ connecting
            if (currentPosNum == 0)
            {
                // do nothing
            }
            //	2, possion list trùng hoàn toàn với session cũ: lấy session cũ
            else if (closedPosNum == 0 && newPosNum == 0)
            {
                if (mSession.GetWeight() == previousSession.GetWeight())
                {
                    mSession.SetSessionId(previousSession.GetSessionId());
                    previousSession.CopyTradingMap(mSession);
                }
                else
                {
                    TerminalAPI::DoShowMessagePopup("ERROR in INIT Client: \n
                                                    Same previous session but weith is different");
                    res = false;
                }
            }
            // 3, possion list trùng một phần (có cái bị close, có new pos): lấy session cũ
            else if (closedPosNum < previousSession.GetClientPositionNumer())
            {
                if (mSession.GetWeight() == previousSession.GetWeight())
                {
                    mSession.SetSessionId(previousSession.GetSessionId());
                    mSession.UpdateLatestPosition(posArr);
                }
                else
                {
                    TerminalAPI::DoShowMessagePopup("ERROR in INIT Client: \n
                                                    Same previous session but weith is different");
                    res = false;
                }
            }
            // 4, possion cũ bị close hết: chờ connecting
            else if (closedPosNum == previousSession.GetClientPositionNumer())
            {
                // do nothing
            }
            else
            {
                TerminalAPI::DoShowMessagePopup("ERROR in INIT Client!!!");
                res = false;
            }
        }
        // server  -> client: 
        // 	1, nếu dữ liệu cũ còn position đang chạy ->  close EA
        //	2, case khacs: chờ connecting
        else if (previousSession.GetMode() == eCPT_MODE_SERVER)
        {
            ulong oldMap[];
            previousSession.GetTradingData();
            int tradingDataSize = ArraySize(oldMap);
            bool isOldTradeIsExisted = false;
            for (i = 0; i < tradingDataSize; i += 2)
            {
                for  (j = 0; j < currentPosNum; j ++)
                {
                    if (oldMap[i] != 0 && oldMap[i + 1] != 0 && oldMap[i + 1] == posArr[j].position_ticket)
                    {
                        isOldTradeIsExisted = true;
                    }
                }
                if (isOldTradeIsExisted) break;
            }
            if (isOldTradeIsExisted)
            {
                TerminalAPI::DoShowMessagePopup("ERROR init SERVER -> CLIENT:\n
                                                client đang có sẵn các Position của position trước đó!! hãy kiểm tra");
                res = false;
            }
        }
        // Unknown -> client: warning nếu đang có postion và chờ connecting
        else
        {
            if (currentPosNum > 0)
            {
                TerminalAPI::DoShowMessagePopup("WARNING init CLIENT:\n
                                                client đang có sẵn các Position!");
            }
        }
        return res;
    }

    void Terminate() override
    {
        int copyTradePosNum = mSession.GetCptPositionNumber();
        if (copyTradePosNum > 0)
        {
            mSession.SaveSession();
        }

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
        // sau khi position added: cần check lại và update event thành DONE
        if (mCopyTradeEventQueue[0].eventId == EV_ADD_NEW_POSITION)
        {
            if (mCopyTradeEventQueue[0].tracking_number == newPos.magic_number)
            {
                mCopyTradeEventQueue[0].status = EVS_DONE;
            }
        }
    }

    void OnPositionClosed(iPosition& closedPos) override
    {
        // sau khi position closed, cần check lại và update event thành DONE
        if (mCopyTradeEventQueue[0].eventId == EV_CLOSED_POSITION)
        {
            if (mCopyTradeEventQueue[0].target_ticket == closedPos.position_ticket)
            {
                mCopyTradeEventQueue[0].status = EVS_DONE;
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
    void SetConnectionState(EnumServerConnectionState newState)
    {
        if (m_state != newState)
        {
            m_state = newState;
            LOGD("Connection state change: " + (string)m_state + "-" + ToString(m_state));
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
        m_pInOutManager.SeekToEndInputFile();
        m_pInOutManager.Init();
        SetConnectionState(eSERVER_CONN_STATE_CONNECTING);
    }
    
    /*
    *   mất kết nối server trong quá trính connecting\ -> action tương tự disconnect trong connected
    */
    void Connecting_OnServerDisconnection()
    {
        SetConnectionState(eSERVER_CONN_STATE_CONNECTED);
    }

    /*
    *   khi server bị tắt đột ngội thì client remove các file output đi.
    */
    void Connecting_OnServerUpdate()
    {
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
        int size = ArraySize(cmdList);
        for(int i = 0; i < size; i++)
        {
            string cmdStr = cmdList[i];
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
                iPosition positions[];
                ParseJsonArrayToPositions(PositonArrayStr, positions);
                if (ArraySize(positions) > 0)
                {
                    // TODO: update logic xác định session sau
                    // tạm thời sẽ close EA trong trường hợp này
                    LOGD("Server đã có connection -> close EA");
                    TerminalAPI::DoCloseEA();
                    return;
                }
                SetConnectionState(eSERVER_CONN_STATE_CONNECTED);
            }
        }
    }

    void Connected_HandleServerCommands(string &cmdList[])
    {
        int size = ArraySize(cmdList);
        string PositonJsonStr = "";
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
                    PositonJsonStr = ParseJsonValue(cmdStr, "positon_info");
                    iPosition newPos = ParseJsonToPosition(PositonJsonStr);
                    OnServer_NewPositionAdded(newPos);
                    break;
                }
                case eCMD_CPT_POS_CLOSED:
                {
                    PositonJsonStr = ParseJsonValue(cmdStr, "positon_info");
                    iPosition closedPos = ParseJsonToPosition(PositonJsonStr);
                    OnServer_NewPositionAdded(closedPos); 
                    break;
                }
                default:
                    // ignore các cmd khác
                    break;
            }
        }
    }

    void OnServer_NewPositionAdded(iPosition &newPos)
    {
        LOGD("new remote position: " + ToString(newPos));
        CopyTradeEvent ev;
        ev.eventId = EV_ADD_NEW_POSITION;
        ev.server_ticket = newPos.position_ticket;
        ev.position_type = newPos.position_type;
        ev.volume = newPos.volume * mSession.GetWeight();
        AddCopytradeEvent(ev);
    }

    void OnServer_PositionClosed(iPosition &closedPos)
    {
        LOGD("remote position closed: " + ToString(closedPos));
        ulong target_ticket = mSession.GetClientTicket(closedPos.position_ticket);
        if (target_ticket == 0)
        {
            LOGD("can not find the target - server-ticket" + (string)closedPos.position_ticket);
            return;
        }
        CopyTradeEvent ev;
        ev.eventId = EV_CLOSED_POSITION;
        ev.server_ticket = closedPos.position_ticket;
        ev.volume = closedPos.volume * mSession.GetWeight();
        ev.position_type = closedPos.position_type;
        ev.target_ticket = target_ticket;
        AddCopytradeEvent(ev);
    }
};