#include "Terminal.mqh"
#include "CommonDatacenter.mqh"
#include "TerminalApi.mqh"
#include "Types.mqh"
#include "Utils.mqh"

class InOutController
{
private:
    Terminal *m_pRemoteTerminal;

    ulong mLastReadPosition;
    ulong mLastTimeAliveReceived;
    ulong mLastTimePingSent;
    ulong mWaitingReconnectingCount;

    RemoteConnectionState m_state;
    void SetConnectionState(RemoteConnectionState newState)
    {
        if (m_state != newState)
        {
            m_state = newState;
            LOGD("Connection state change: " + (string)m_state + "-" + ToString(m_state));
            
            // reset vị trí đọc file.
            if (m_state != eREMOTE_STATE_CONNECTING && m_state != eREMOTE_STATE_CONNECTED)
            {
                mLastReadPosition = 0;
            }

            // lấy time đầu tiên khi kết nối.
            if (m_state == eREMOTE_STATE_CONNECTED)
            {
                mLastTimeAliveReceived = TimeLocal();
                mLastTimePingSent = mLastTimeAliveReceived;
            }
        }
    }
    /**********************************************************************************
    *
    *  init/terminate function
    *
    ***********************************************************************************/
private:
    void InitFilesPath()
    {
        bool isF1Exist = FileIsExist(FILE_DATA_EXCHANGE_F1, FILE_COMMON);
        bool isF2Exist = FileIsExist(FILE_DATA_EXCHANGE_F2, FILE_COMMON);
        LOGE("files: F1=" + ToString(isF1Exist) + " and F2=" + ToString(isF2Exist));
        if (isF1Exist && isF2Exist)
        {
            CommonDatacenter::sFILE_OUTPUT = "";
            CommonDatacenter::sFILE_INPUT = "";
        }
        // take F1
        else if (!isF1Exist)
        {
            CommonDatacenter::sFILE_OUTPUT = FILE_DATA_EXCHANGE_F1;
            CommonDatacenter::sFILE_INPUT = FILE_DATA_EXCHANGE_F2;
        }
        // take F2
        else if (!isF2Exist)
        {
            CommonDatacenter::sFILE_OUTPUT = FILE_DATA_EXCHANGE_F2;
            CommonDatacenter::sFILE_INPUT = FILE_DATA_EXCHANGE_F1;
        }
        else
        {
            // never land here
        }
    }
    void CreateOutputFile()
    {
        if (CommonDatacenter::sFILE_OUTPUT == "")
        {
            return;
        }
        int h = FileOpen(CommonDatacenter::sFILE_OUTPUT, FILE_WRITE | FILE_TXT | FILE_COMMON);
        if(h != INVALID_HANDLE)
        {
            FileClose(h);
            LOGD("Created output file: " + CommonDatacenter::sFILE_OUTPUT);
        }
        else
        {
            LOGE("Failed to create file: " + CommonDatacenter::sFILE_OUTPUT);
        }
    }
    void RemoveOutputFile()
    {
        if(FileIsExist(CommonDatacenter::sFILE_OUTPUT, FILE_COMMON))
        {
            FileDelete(CommonDatacenter::sFILE_OUTPUT, FILE_COMMON);
            LOGD("Removed output file: " + CommonDatacenter::sFILE_OUTPUT);
        }
    }
public:
    void init(Terminal* remoteTerminal, Terminal* localTerminal)
    {  
        m_pRemoteTerminal = remoteTerminal;

        // tạo thư mục để chắc chắn thư mục tồn tại
        if (!FileIsExist(FOLDER_EA_DIR, FILE_COMMON))
        {
            FolderCreate(FOLDER_EA_DIR, FILE_COMMON);
        }
        InitFilesPath();
        if (CommonDatacenter::sFILE_OUTPUT == "" || CommonDatacenter::sFILE_INPUT == "")
        {
            LOGE("File for data exchange is not set, force exit EA");
            TerminalAPI::DoCloseEA();
            return;
        }
        CreateOutputFile();
        SetConnectionState(eREMOTE_STATE_WAIT_INPUT);
    }
    void terminate()
    {
        RemoveOutputFile();
    }
    RemoteConnectionState GetState()
    {
        return m_state;
    }

    /**********************************************************************************
    *
    *  send data to the remote terminal
    *
    ***********************************************************************************/
public:
    void SendData(string jsonData)
    {
        if (m_state != eREMOTE_STATE_CONNECTED && m_state != eREMOTE_STATE_CONNECTING)
        {
            LOGE("can not send data, current state: " + ToString(m_state));
            return;
        }
        if (CommonDatacenter::sFILE_OUTPUT == "")
        {
            LOGE("sFILE_OUTPUT is empty");
            return;
        }

        int handle = FileOpen(CommonDatacenter::sFILE_OUTPUT, FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_ANSI|FILE_COMMON);
        if(handle != INVALID_HANDLE)
        {
            FileSeek(handle, 0, SEEK_END);
            FileWrite(handle, jsonData);
            FileClose(handle);
            LOGD(">>> SEND: " + jsonData);
        }
        else
        {
            LOGE("Failed to open file: " + CommonDatacenter::sFILE_OUTPUT);
        }
    }
    /***********************************************************************
    *
    *   Connection functions.
    *
    ***********************************************************************/
private:
    void DoSendAliveMsg()
    {
        string jsonData = "{}";
        SendData(ToJson(eCMD_PING_ALIVE, jsonData));
    }

public:
    void DoWaitInput()
    {
        if (m_state == eREMOTE_STATE_WAIT_INPUT)
        {
            // input file được tạo ra bởi remote terminal -> chuyển sang connecting và chờ connect.
            if (FileIsExist(CommonDatacenter::sFILE_INPUT, FILE_COMMON))
            {
                LOGD("Input file detected: " + CommonDatacenter::sFILE_INPUT);
                SetConnectionState(eREMOTE_STATE_CONNECTING);
                SendData(ToJson(eCMD_DO_CONNECTING, "{}"));
            }
        }
        else
        {
            LOGD("Unexpected state: " + (string)m_state);
        }
    }

    void OnDisconnectionDetected()
    {
        LOGD("@@ Remote disconnected");
        RemoveOutputFile();
        mLastReadPosition = 0;
        mLastTimeAliveReceived = 0;
        mLastTimePingSent = 0;
        CommonDatacenter::sFILE_OUTPUT = "";
        CommonDatacenter::sFILE_INPUT = "";
        mWaitingReconnectingCount = 0;
        SetConnectionState(eREMOTE_STATE_RECONNECTING);
    }

    void DoReconnecting()
    {
        if (m_state != eREMOTE_STATE_RECONNECTING)
        {
            LOGE("Not in reconnecting state, cannot do reconnecting.");
            return;
        }
        mWaitingReconnectingCount++;
        // chờ 3s trước khi thực hiện connecting.
        if (mWaitingReconnectingCount > 3)
        {
            InitFilesPath();
            if (CommonDatacenter::sFILE_OUTPUT == "" || CommonDatacenter::sFILE_INPUT == "")
            {
                LOGE("File for data exchange is not set, force exit EA");
                TerminalAPI::DoCloseEA();
                return;
            }
            CreateOutputFile();
            SetConnectionState(eREMOTE_STATE_WAIT_INPUT);
        }
    }

    /***********************************************************************
    *
    *   Polling functions.
    *
    ***********************************************************************/
    void DoPoll()
    {
        if (!FileIsExist(CommonDatacenter::sFILE_INPUT, FILE_COMMON))
        {
            static int reduceLogCount = 0;
            if (reduceLogCount % 60 == 0) // log every 60 times
            {
                LOGE("sFILE_INPUT does not exist: " + CommonDatacenter::sFILE_INPUT);
            }
            reduceLogCount++;

            // nếu file input bị mất thì chuyển sang WAIT_INPUT để chờ file input xuất hiện lại.
            if (m_state == eREMOTE_STATE_CONNECTED || m_state == eREMOTE_STATE_CONNECTING)
            {
                OnDisconnectionDetected();
            }
            return;
        }

        // nếu ko nhận dc eCMD_PING_ALIVE trong hơn 60 giây, coi như đã mất kết nối.
        // chuyển trạng thái sang connecting để chờ kết nối lại.
        if (m_state == eREMOTE_STATE_CONNECTED)
        {
            datetime now = TimeLocal();
            if (now - mLastTimeAliveReceived >= 60)
            {
                LOGD("No alive signal received for 60 seconds");
                OnDisconnectionDetected();
                return;
            }
            if (now - mLastTimePingSent >= 30)
            {
                DoSendAliveMsg();
                mLastTimePingSent = now;
            }
        }

        // bắt đầu đọc file input và xử lý các command nếu có.
        static int openFileErrorCount = 0;
        int handle = FileOpen(CommonDatacenter::sFILE_INPUT, FILE_READ|FILE_TXT|FILE_SHARE_WRITE|FILE_ANSI|FILE_COMMON);
        if(handle != INVALID_HANDLE)
        {
            openFileErrorCount = 0;

            // Check file size before seeking
            FileSeek(handle, 0, SEEK_END);
            ulong end_pos = FileTell(handle);
            if (end_pos < mLastReadPosition)
            {
                LOGD("File size (" + (string)end_pos + ") is less than last read position (" + (string)mLastReadPosition + "). Resetting read position.");
                mLastReadPosition = 0;
            }

            bool ExistedFlag[eCMD_MAX] = {false};
            string cmdJsonStr[eCMD_MAX] = {""};

            FileSeek(handle, mLastReadPosition, SEEK_SET);
            ulong cmd = 0;
            while(!FileIsEnding(handle))
            {
                string line = FileReadString(handle);

                if(StringLen(line) > 0)
                {
                    // Parse cmdId:
                    cmd = ParseIntValue(line, "cmd");

                    // parse tất cả command và lưu giá trị cuối cùng vào mảng.
                    if (cmd > eCMD_UNKNOWN && cmd < eCMD_MAX)
                    {
                        string json_str = ParseJsonValue(line, "cmd_data");
                        ExistedFlag[cmd] = true;
                        cmdJsonStr[cmd] = json_str;
                    }
                    else
                    {
                        LOGE("Invalid cmd in line: " + line);
                    }
                }
            }
            mLastReadPosition = FileTell(handle);
            FileClose(handle);

            // xử lý từng command nhận được với latest cmd_data
            for (cmd = 0; cmd < eCMD_MAX; cmd++)
            {
                if (ExistedFlag[cmd] == true)
                {
                    double remote_closedVolumeBySLSO = 0;
                    double remote_aliveVolume = 0;
                    switch (m_state)
                    {
                        case eREMOTE_STATE_CONNECTING:
                            if (cmd == eCMD_ON_CONNECTED)
                            {
                                EnumTerminalType remote_terminalType = (EnumTerminalType)ParseIntValue(cmdJsonStr[cmd], "terminal_type");
                                remote_closedVolumeBySLSO = ParseDoubleValue(cmdJsonStr[cmd], "closed_volume_bySLSO");
                                remote_aliveVolume = ParseDoubleValue(cmdJsonStr[cmd], "alive_volume");
                                m_pRemoteTerminal.OnRemote_Connected(remote_terminalType, remote_closedVolumeBySLSO, remote_aliveVolume);
                                SetConnectionState(eREMOTE_STATE_CONNECTED);
                            }
                            // in CONECTING, receive DO_CONNECTING -> send ON_CONNECTED
                            else if (cmd == eCMD_DO_CONNECTING)
                            {
                                m_pRemoteTerminal.OnRemote_Connecting();
                            }
                            else
                            {
                                LOGD("Still connecting... Received cmd: " + (string)cmd);
                            }
                            break;
                        case eREMOTE_STATE_CONNECTED:
                            if (cmd == eCMD_ON_SLSO)
                            {
                                remote_closedVolumeBySLSO = ParseDoubleValue(cmdJsonStr[cmd], "closed_volume_bySLSO");
                                remote_aliveVolume = ParseDoubleValue(cmdJsonStr[cmd], "alive_volume");
                                m_pRemoteTerminal.OnRemote_OnSLSO(remote_closedVolumeBySLSO, remote_aliveVolume);
                            }
                            else if (cmd == eCMD_PING_ALIVE)
                            {
                                mLastTimeAliveReceived = TimeLocal();
                            }
                            else if (cmd == eCMD_ON_UPDATE)
                            {
                                remote_closedVolumeBySLSO = ParseDoubleValue(cmdJsonStr[cmd], "closed_volume_bySLSO");
                                remote_aliveVolume = ParseDoubleValue(cmdJsonStr[cmd], "alive_volume");
                                m_pRemoteTerminal.OnRemote_Update(remote_closedVolumeBySLSO, remote_aliveVolume);
                            }
                            else
                            {
                                LOGE("Not expected cmd: " + (string)cmd + " in state: " + (string)m_state);
                            }
                            break;
                        default:
                            LOGE("Not expected state: " + (string)m_state);
                            break;
                    }
                }
            }
        }
        else
        {
            LOGE("Failed to open file: " + CommonDatacenter::sFILE_INPUT);
            openFileErrorCount += 1;
            if (openFileErrorCount == 10)
            {
                LOGE("Failed to open file for 10 times, resetting connection state.");
                OnDisconnectionDetected();
            }
        }
    }
};