#include "Terminal.mqh"
#include "CommonDatacenter.mqh"
#include "Types.mqh"
#include "Utils.mqh"

class RemoteTerminal : public Terminal
{
private:
    /*
    * connection state to remote terminal EA.
    */
    RemoteConnectionState m_state;

    // last time receive data from remote terminal, used to detect disconnection.
    ulong mLastTimeAliveReceived;
    ulong mLastTimePingSent;
    void SetConnectionState(RemoteConnectionState newState)
    {
        if (m_state != newState)
        {
            m_state = newState;
            LOGD("Remote connection state changed: " + (string)m_state);
            
            // reset vị trí đọc file.
            if (m_state == eREMOTE_STATE_NOT_CONNECTED)
            {
                mLastReadPosition = 0;
            }

            // lấy time đầu tiên khi kết nối.
            if (m_state == eREMOTE_STATE_CONNECTED)
            {
                mLastTimeAliveReceived = TimeCurrent();
                mLastTimePingSent = mLastTimeAliveReceived;
            }
        }
    }

    Terminal *m_pLocalTerminal;
    ulong mLastReadPosition;

    /*
    * lưu giá trị volume đã bị đóng bởi SL hoặc StopOut từ phía remote
    * và volume còn lại đang mở, để phục vụ cho việc tính toán logic auto TP ở local terminal.
    */
    double m_closedVolumeBySLSO;
    double m_alivePositionsVolume;

public:
    RemoteTerminal() 
    :   m_pLocalTerminal(NULL), 
        m_state(eREMOTE_STATE_NOT_CONNECTED), 
        mLastReadPosition(0),
        m_closedVolumeBySLSO(0.0), m_alivePositionsVolume(0.0)
    {}

    ~RemoteTerminal() {}

    /***********************************************************************
    *
    *   các hàm virtual
    *
    ***********************************************************************/
    void init(Terminal* remoteTerminal) override
    {
        m_pLocalTerminal = remoteTerminal;
    }
    void termniate() override
    {
    }
    void ResetTradingSession() override
    {
        m_closedVolumeBySLSO = 0.0;
        m_alivePositionsVolume = 0.0;
    }
    double GetAliveVolume() override
    {
        return m_alivePositionsVolume;
    }
    RemoteConnectionState GetConnectionState()
    {
        return m_state;
    }

    /***********************************************************************
    *
    *   Polling functions.
    *
    ***********************************************************************/
    void DoPoll()
    {
        if (CommonDatacenter::sFILE_INPUT == "")
        {
            LOGE("sFILE_INPUT is empty");
            SetConnectionState(eREMOTE_STATE_NOT_CONNECTED);
            return;
        }

        if (!FileIsExist(CommonDatacenter::sFILE_INPUT, FILE_COMMON))
        {
            static int reduceLogCount = 0;
            if (reduceLogCount % 60 == 0) // log every 60 times
            {
                LOGE("sFILE_INPUT does not exist: " + CommonDatacenter::sFILE_INPUT);
            }
            reduceLogCount++;
            if (m_state != eREMOTE_STATE_NOT_CONNECTED)
            {
                // state chuyển từ connected  -> not connect
                //                 connecting -> not connect
                // => thực hiện reset file, và resonnecting
                m_pLocalTerminal.OnRemote_Disconnected();

                SetConnectionState(eREMOTE_STATE_NOT_CONNECTED);
            }
            return;
        }

        // trong trường hợp state đang not connecect,
        // file được tạo ra bởi remote terminal -> chuyển sang connecting và chờ connect.
        if (m_state == eREMOTE_STATE_NOT_CONNECTED)
        {
            LOGD("File detected, trying to connect...");
            SetConnectionState(eREMOTE_STATE_CONNECTING);
        }

        // nếu ko nhận dc eCMD_PING_ALIVE trong hơn 60 giây, coi như đã mất kết nối.
        // chuyển trạng thái sang connecting để chờ kết nối lại.
        if (m_state == eREMOTE_STATE_CONNECTED)
        {
            datetime now = TimeCurrent();
            if (now - mLastTimeAliveReceived >= 60)
            {
                LOGD("No alive signal received for 60 seconds");
                SetConnectionState(eREMOTE_STATE_CONNECTING);
            }
            if (now - mLastTimePingSent >= 30)
            {
                m_pLocalTerminal.DoSendAliveMsg();
                mLastTimePingSent = now;
            }
        }
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
                    switch (m_state)
                    {
                        case eREMOTE_STATE_CONNECTING:
                            if (cmd == eCMD_ON_CONNECTED)
                            {
                                m_closedVolumeBySLSO = ParseDoubleValue(cmdJsonStr[cmd], "closed_volume_bySLSO");
                                m_alivePositionsVolume = ParseDoubleValue(cmdJsonStr[cmd], "alive_volume");
                                m_pLocalTerminal.OnRemote_Connected(m_closedVolumeBySLSO, m_alivePositionsVolume);
                                SetConnectionState(eREMOTE_STATE_CONNECTED);
                            }
                            else if (cmd == eCMD_DO_CONNECTING)
                            {
                                m_pLocalTerminal.OnRemote_DoConnecting();
                            }
                            else
                            {
                                LOGD("Still connecting... Received cmd: " + (string)cmd);
                            }
                            break;
                        case eREMOTE_STATE_CONNECTED:
                            if (cmd == eCMD_ON_SLSO)
                            {
                                m_closedVolumeBySLSO = ParseDoubleValue(cmdJsonStr[cmd], "closed_volume_bySLSO");
                                m_alivePositionsVolume = ParseDoubleValue(cmdJsonStr[cmd], "alive_volume");
                                m_pLocalTerminal.OnRemote_SLSO(m_closedVolumeBySLSO, m_alivePositionsVolume);
                            }
                            else if (cmd == eCMD_PING_ALIVE)
                            {
                                mLastTimeAliveReceived = TimeCurrent();
                            }
                            else if (cmd == eCMD_ON_UPDATE)
                            {
                                m_closedVolumeBySLSO = ParseDoubleValue(cmdJsonStr[cmd], "closed_volume_bySLSO");
                                m_alivePositionsVolume = ParseDoubleValue(cmdJsonStr[cmd], "alive_volume");
                                m_pLocalTerminal.OnRemote_Update(m_closedVolumeBySLSO, m_alivePositionsVolume);
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
            if (openFileErrorCount == 15)
            {
                LOGE("Failed to open file for 15 times, resetting connection state.");
                SetConnectionState(eREMOTE_STATE_NOT_CONNECTED);
            }
        }
    }
};