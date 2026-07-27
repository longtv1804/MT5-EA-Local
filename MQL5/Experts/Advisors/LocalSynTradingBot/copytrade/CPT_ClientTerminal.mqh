#include "../common/Types.mqh"
#include "../common/Utils.mqh"
#include "../common/Logging.mqh"
#include "../common/TradeUtils.mqh"
#include "../queue/Event.mqh"
#include "../queue/EventUtils.mqh"
#include "../lib/PointerList.mqh"
#include "CPT_LocalTerminal.mqh"
#include "CPT_Strategy.mqh"
#include "CPT_Strategy_Factory.mqh"

class CPT_ClientTerminal : public CPT_LocalTerminal
{
private:
    EnumStrategyPlanId mPlanId;
    double mWeight;
    int mConnectionSessionId;
    PointerList<CPT_Strategy> mStrategyList;

    /**********************************************************************************
    *
    *   init/terminate
    *
    ***********************************************************************************/
public:
    CPT_ClientTerminal(double weight) 
    :   CPT_LocalTerminal()
    {
        mPlanId = EnumStrategyPlanId::PLAN_ID_1;
        mWeight = weight;
        mConnectionSessionId = 0;
        SetConnectionState(eSERVER_CONN_STATE_UNKNOWN);
    }

    virtual ~CPT_ClientTerminal()
    {
        for (int i = 0; i < mStrategyList.Size(); i++)
        {
            delete mStrategyList.At(i);
        }
        mStrategyList.Clear();
    }

    bool Init(CPT_InOutManager* inOutController) override
    {
        CPT_LocalTerminal::Init(inOutController);
        m_pInOutManager.InitFilesPath();
        SetConnectionState(eSERVER_CONN_STATE_DISCONNECTED);
        return true;
    }

    bool InitStrategy(int planId) override
    {
        if (planId < EnumStrategyPlanId::PLAN_ID_1 || planId >= EnumStrategyPlanId::PLAN_ID_MAX)
        {
            TerminalAPI::DoShowMessagePopup("Wrong Plan Id!!!");
            return false;
        }
        mPlanId = (EnumStrategyPlanId)planId;
        CPT_Strategy* pStrategy = NULL;
        switch(planId)
        {
            case EnumStrategyPlanId::PLAN_ID_1:
                pStrategy = CPT_Strategy_Factory::Make(mPlanId, eSPT_BUY_SELL, mWeight);
                if (pStrategy)
                {
                    mStrategyList.Add(pStrategy);
                }
                break;
            case EnumStrategyPlanId::PLAN_ID_3:
            case EnumStrategyPlanId::PLAN_ID_4:
                pStrategy = CPT_Strategy_Factory::Make(mPlanId, eSPT_BUY, mWeight);
                if (pStrategy)
                {
                    mStrategyList.Add(pStrategy);
                }
                pStrategy = CPT_Strategy_Factory::Make(mPlanId, eSPT_SELL, mWeight);
                if (pStrategy)
                {
                    mStrategyList.Add(pStrategy);
                }
                break;
            default:
                break;
        }

        // init strategies
        int i = 0;
        bool res = mStrategyList.Size() > 0;
        for (i = 0; i < mStrategyList.Size(); i++)
        {
            res = mStrategyList.At(i).Init();
            if (res == false) break;
        }
        if (res == false) 
        {
            for (i = 0; i < mStrategyList.Size(); i++)
            {
                delete mStrategyList.At(i);
            }
            mStrategyList.Clear();
        }
        return res;
    }

    void SetStrategyParam(ByteBuffer& param) override
    {
        for (int i = 0; i < mStrategyList.Size(); i++)
        {
            Event ev = ObtainEvent(EV_STRATEGY_UPDATE_PARAMS, mStrategyList.At(i));
            param.CopyBuffer(ev.data);
            SendEvent(ev);
        }
    }

    void Terminate() override
    {
        LOGD("terminate ClientTerminal...");
        
        for (int i = 0; i < mStrategyList.Size(); i++)
        {
            CPT_Strategy* pStrategy = mStrategyList.At(i);
            pStrategy.Terminate();
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
        mConnectionSessionId = server_sessionId;

        int server_posNum = ArraySize(server_positions);
        int now_client_posNum = ArraySize(now_client_positions);
        LOGD("CMD-UPDATE detected: remote-session:" + (string)server_sessionId + " symbol:" + serverSymbol + " server-posnum:" + (string)server_posNum);
        LOGD("my-session:" +(string)mConnectionSessionId + " symbol:" + _Symbol + " client-posnum:" + (string)now_client_posNum);

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

        for (int i = 0; i < mStrategyList.Size(); i++)
        {
            mStrategyList.At(i).OnServerUpdate(server_positions, now_client_positions);
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
        if (session != mConnectionSessionId)
        {
            LOGE("ERROR: server-session: " + (string)session + " my-session: " + (string)mConnectionSessionId);
            return;
        }

        LOGD(">>> " + (string)session + " " + ToString(newPos));
        for (int i = 0; i < mStrategyList.Size(); i++)
        {
            mStrategyList.At(i).OnServer_NewPositionAdded(newPos);
        }
    }

    void OnServer_PositionClosed(int session, iPosition &closedPos)
    {
        if (session != mConnectionSessionId)
        {
            LOGE("ERROR: server-session: " + (string)session + " my-session: " + (string)mConnectionSessionId);
            return;
        }

        LOGD(">>> " + (string)session + " " + ToString(closedPos));
        for (int i = 0; i < mStrategyList.Size(); i++)
        {
            mStrategyList.At(i).OnServer_PositionClosed(closedPos);
        }
    }

    /**********************************************************************************
    *
    *   Possions changed
    *
    ***********************************************************************************/
    void OnPositionAdded(const iPosition& newPos) override
    {
        for (int i = 0; i < mStrategyList.Size(); i++)
        {
            mStrategyList.At(i).OnLocal_PositionAdded(newPos);
        }
    }

    void OnPositionClosed(const iPosition& closedPos) override
    {
        for (int i = 0; i < mStrategyList.Size(); i++)
        {
            mStrategyList.At(i).OnLocal_PositionClosed(closedPos);
        }
    }
};