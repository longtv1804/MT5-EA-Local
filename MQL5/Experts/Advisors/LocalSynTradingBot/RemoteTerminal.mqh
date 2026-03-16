#include "Terminal.mqh"
#include "LocalTerminal.mqh"
#include "CommonDatacenter.mqh"
#include "Types.mqh"
#include "Utils.mqh"

#include <trade/trade.mqh>

class RemoteTerminal
{
private:    /*
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

    LocalTerminal *m_pLocalTerminal;
    ulong mLastReadPosition;

    /*
    * lưu giá trị volume đã bị đóng bở SL hoặc StopOut từ phía remote.
    */
    double m_closedVolumeBySLSO;
    double m_alivePositionsVolume;

public:
    RemoteTerminal(LocalTerminal *pLocalTerminal) 
    :   m_pLocalTerminal(pLocalTerminal), 
        m_state(eREMOTE_STATE_NOT_CONNECTED), 
        mLastReadPosition(0),
        m_closedVolumeBySLSO(0.0), m_alivePositionsVolume(0.0)
    {}

    ~RemoteTerminal() {}

    RemoteConnectionState GetConnectionState()
    {
        return m_state;
    }

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
                m_pLocalTerminal.DoReConnecting();

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

        int handle = FileOpen(CommonDatacenter::sFILE_INPUT, FILE_READ|FILE_TXT|FILE_SHARE_WRITE|FILE_ANSI|FILE_COMMON);
        if(handle != INVALID_HANDLE)
        {
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
            while(!FileIsEnding(handle))
            {
                string line = FileReadString(handle);

                if(StringLen(line) > 0)
                {
                    // Parse cmdId:
                    ulong cmd = ParseIntValue(line, "cmd");

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
            for (ulong cmd = 0; cmd < eCMD_MAX; cmd++)
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
            SetConnectionState(eREMOTE_STATE_NOT_CONNECTED);
        }
    }

    /**********************************************************************************
    *
    *  static functions
    *
    ***********************************************************************************/
private:

    // Static function: Parse a single JSON object to iPosition
    static iPosition ParseJsonToPosition(const string &jsonObj)
    {
        iPosition info;
        ZeroMemory(info);
        int fpos;
        fpos = StringFind(jsonObj, "\"position_ticket\":");
        if(fpos>=0) info.position_ticket = StringToInteger(GetJsonValue(jsonObj, "position_ticket"));
        fpos = StringFind(jsonObj, "\"symbol\":");
        if(fpos>=0) info.symbol = GetJsonString(jsonObj, "symbol");
        fpos = StringFind(jsonObj, "\"position_type\":");
        if(fpos>=0) info.position_type = (ENUM_POSITION_TYPE)(StringToInteger(GetJsonValue(jsonObj, "position_type")));
        fpos = StringFind(jsonObj, "\"status\":");
        if(fpos>=0) info.status = (EnumPositionStatus)(StringToInteger(GetJsonValue(jsonObj, "status")));
        fpos = StringFind(jsonObj, "\"volume\":");
        if(fpos>=0) info.volume = StringToDouble(GetJsonValue(jsonObj, "volume"));
        fpos = StringFind(jsonObj, "\"price_open\":");
        if(fpos>=0) info.price_open = StringToDouble(GetJsonValue(jsonObj, "price_open"));
        fpos = StringFind(jsonObj, "\"time_open\":");
        if(fpos>=0) info.time_open = StringToTime(GetJsonValue(jsonObj, "time_open"));
        fpos = StringFind(jsonObj, "\"open_reason\":");
        if(fpos>=0) info.open_reason = (ENUM_POSITION_REASON)StringToInteger(GetJsonValue(jsonObj, "open_reason"));
        fpos = StringFind(jsonObj, "\"price_close\":");
        if(fpos>=0) info.price_close = StringToDouble(GetJsonValue(jsonObj, "price_close"));
        fpos = StringFind(jsonObj, "\"time_close\":");
        if(fpos>=0) info.time_close = StringToTime(GetJsonValue(jsonObj, "time_close"));
        fpos = StringFind(jsonObj, "\"close_reason\":");
        if(fpos>=0) info.close_reason = (ENUM_DEAL_REASON)StringToInteger(GetJsonValue(jsonObj, "close_reason"));
        return info;
    }

    // Static function: Parse JSON array to iPosition array
    static void ParseJsonArrayToPositions(const string &jsonArr, iPosition &positions[])
    {
        int pos = 0;
        while(pos < StringLen(jsonArr))
        {
            int obj_start = StringFind(jsonArr, "{", pos);
            if(obj_start < 0) break;
            int obj_end = StringFind(jsonArr, "}", obj_start);
            if(obj_end < 0) break;
            string obj = StringSubstr(jsonArr, obj_start, obj_end-obj_start+1);
            iPosition info = ParseJsonToPosition(obj);
            int n = ArraySize(positions);
            ArrayResize(positions, n+1);
            positions[n] = info;
            pos = obj_end+1;
        }
    }

    // lấy giá trị của key trong json string, nếu có.
    static string ParseJsonValue(const string &json,const string &key)
    {
        string pattern="\""+key+"\":";
        int pos=StringFind(json,pattern);
        if(pos<0) return "";

        int value_start=pos+StringLen(pattern);

        // skip whitespace
        while(value_start<StringLen(json))
        {
            ushort c=StringGetCharacter(json,value_start);
            if(c!=' ' && c!='\t' && c!='\n' && c!='\r')
                break;
            value_start++;
        }

        if(value_start>=StringLen(json))
            return "";

        ushort first=StringGetCharacter(json,value_start);

        // STRING
        if(first=='"')
        {
            value_start++;
            int value_end=StringFind(json,"\"",value_start);
            if(value_end>value_start)
            {
                return StringSubstr(json,value_start,value_end-value_start);
            }
        }

        // OBJECT
        if(first=='{')
        {
            int depth=1;
            int i=value_start+1;

            while(i<StringLen(json) && depth>0)
            {
                ushort c=StringGetCharacter(json,i);
                if(c=='{') depth++;
                if(c=='}') depth--;
                i++;
            }

            if(depth==0)
            {
                return StringSubstr(json,value_start,i-value_start);
            }
        }

        // ARRAY
        if(first=='[')
        {
            int depth=1;
            int i=value_start+1;

            while(i<StringLen(json) && depth>0)
            {
                ushort c=StringGetCharacter(json,i);
                if(c=='[') depth++;
                if(c==']') depth--;
                i++;
            }

            if(depth==0)
                return StringSubstr(json,value_start,i-value_start);
        }

        // NUMBER / BOOL / NULL
        int i=value_start;
        while(i<StringLen(json))
        {
            ushort c=StringGetCharacter(json,i);
            if(c==',' || c=='}' || c==']')
                break;
            i++;
        }

        if(i>value_start)
        {
            return Trim(StringSubstr(json,value_start,i-value_start));
        }

        return "";
    }

    static double ParseDoubleValue(const string &json, const string &key)
    {
        string value_str = ParseJsonValue(json, key);
        if (value_str != "")
        {
            return StringToDouble(value_str);
        }
        else
        {
            LOGE("Key not found or value is empty: " + key + " in json: " + json);
        }
        return 0.0;
    }
    static int ParseIntValue(const string &json, const string &key)
    {
        string value_str = ParseJsonValue(json, key);
        if (value_str != "")
        {
            return StringToInteger(value_str);
        }
        else
        {
            LOGE("Key not found or value is empty: " + key + " in json: " + json);
        }
        return 0;
    }
};