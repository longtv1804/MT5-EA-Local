#include "../common/Types.mqh"
#include "CPT_LocalTerminal.mqh"
#include "CPT_CopyTradeSession.mqh"

class CPT_ClientTerminal : public CPT_LocalTerminal
{
private:
    CPT_CopyTradeSession mSession;

public:
    CPT_ClientTerminal(double weight) 
    :   CPT_LocalTerminal(),
        mSession(eCPT_MODE_SERVER, 0, weight) 
    {
        m_state = eSERVER_CONN_STATE_UNKNOWN;
    }

    void OnPositionAdded(iPosition& newPos) {}
    void OnPositionClosed(iPosition& newPos) {}

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
        // 1: client -> client
        if (previousSession.GetMode() == eCPT_MODE_CLIENT)
        {
            // không có position nào đang chạy
            if (currentPosNum == 0)
            {
                // do nothing: chờ update session id từ server
            }
            // ko có pos bị closed + ko có pos mới -> vẫn là session cũ đang chạy
            else if (closedPosNum == 0 && newPosNum == 0)
            {
                if (mSession.GetWeight() == previousSession.GetWeigth())
                {
                    mSession.SetSessionId(previousSession.GetSessionId());
                    previousSession.CopyTradingMap(mSession);
                }
                else
                {
                    TerminalAPI::DoShowMessagePopup("ERROR in INIT Client: \nSame previous session but weith is different");
                    res = false;
                }
            }
            else
            {
                TerminalAPI::DoShowMessagePopup("ERROR in INIT Client!!!");
                res = false;
            }
        }
        // 2: server -> client
        // 3: ko detect dc mode trc đó
        else
        {
            if (currentPosNum > 0)
            {
                TerminalAPI::DoShowMessagePopup("ERROR in INIT Client: \nclient đang có sẵn các Position!");
                res = false;
            }
            else
            {
                 // do nothing: chờ update session id từ server
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
        bool isInputExisted = m_pInOutManager.CheckInputFile();
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
                    string cmdList[];
                    int cmdNum = m_pInOutManager.PollData(cmdList);
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
                    string cmdList[];
                    int cmdNum = m_pInOutManager.PollData(cmdList);
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
                LOGD("cmd UPDATE detected");
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
                    string PositonJsonStr = ParseJsonValue(cmdStr, "positon_info");
                    iPosition newPos = ParseJsonToPosition(PositonJsonStr);
                    OnServer_NewPositionAdded(newPos);
                    break;
                }
                case eCMD_CPT_POS_CLOSED:
                {
                    string PositonJsonStr = ParseJsonValue(cmdStr, "positon_info");
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
        double lot = mWeigthNumber * newPos.volume;
        TerminalAPI::DoOpenNowPosition(lot);
    }

    void OnServer_PositionClosed(iPosition &closedPos)
    {
    }
};