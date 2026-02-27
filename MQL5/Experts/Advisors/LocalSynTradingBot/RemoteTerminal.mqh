#include "Terminal.mqh"
#include "LocalTerminal.mqh"
#include "CommonDatacenter.mqh"
#include "Types.mqh"
#include "Utils.mqh"

#include <trade/trade.mqh>

class RemoteTerminal  : public Terminal
{
private:
    LocalTerminal *m_pLocalTerminal;
    ulong mLastReadPosition;

public:
    RemoteTerminal(LocalTerminal *pLocalTerminal) : m_pLocalTerminal(pLocalTerminal) {}
    ~RemoteTerminal() {}

    void DoPoll()
    {
        if (CommonDatacenter::sFILE_INPUT == "")
        {
            LOGE("sFILE_INPUT is empty");
            return;
        }
        // Check if file exists
        if (!FileIsExist(CommonDatacenter::sFILE_INPUT, FILE_COMMON))
        {
            static int reduceLogCount = 0;
            if (reduceLogCount % 60 == 0) // log every 60 times
            {
                LOGE("sFILE_INPUT does not exist: " + CommonDatacenter::sFILE_INPUT);
            }
            reduceLogCount++;
            return;
        }
        int handle = FileOpen(CommonDatacenter::sFILE_INPUT, FILE_READ|FILE_TXT|FILE_SHARE_WRITE|FILE_ANSI|FILE_COMMON);
        if(handle != INVALID_HANDLE)
        {
            iPosition positions[];
            ulong cmd = eCMD_UNKNOWN;
            bool isDataParsed = false;
            int dataLineCount = 0;

            // Check file size before seeking
            FileSeek(handle, 0, SEEK_END);
            ulong end_pos = FileTell(handle);
            if (end_pos < mLastReadPosition)
            {
                LOGD("File size (" + (string)end_pos + ") is less than last read position (" + (string)mLastReadPosition + "). Resetting read position.");
                mLastReadPosition = 0;
            }

            FileSeek(handle, mLastReadPosition, SEEK_SET);
            while(!FileIsEnding(handle))
            {
                string line = FileReadString(handle);
                dataLineCount += 1;
                if(StringLen(line) > 0)
                {
                    // chỉ lấy command ID có priority cao nhất, và data cuối cùng
                    // bởi vì có thể có nhiều cmd được ghi vào cùng một lúc.

                    // Parse cmdId:
                    ulong temp_cmd = eCMD_UNKNOWN;
                    int cmd_pos = StringFind(line, "\"cmd\":");
                    if(cmd_pos >= 0)
                    {
                        int cmd_start = cmd_pos + 6;
                        int cmd_end = StringFind(line, ",", cmd_start);
                        if(cmd_end > cmd_start)
                        {
                            temp_cmd = (ulong)StringToInteger(StringSubstr(line, cmd_start, cmd_end-cmd_start));
                        }
                    }
                    if (temp_cmd < cmd)
                    {
                        cmd = temp_cmd;
                    }
                    
                    // Parse data array
                    // only take positions if this is end of file.
                    if (FileIsEnding(handle))
                    {
                        int data_pos = StringFind(line, "\"curent_positions\":[");
                        if(data_pos >= 0)
                        {
                            int arr_start = data_pos + 20;
                            int arr_end = StringFind(line, "]", arr_start);
                            if(arr_end > arr_start)
                            {
                                string arr_content = StringSubstr(line, arr_start, arr_end-arr_start);
                                RemoteTerminal::ParseJsonArrayToPositions(arr_content, positions);
                            }
                        }
                        isDataParsed = true;
                    }
                }
            }
            mLastReadPosition = FileTell(handle);
            FileClose(handle);

            if (dataLineCount > 1)
            {
                LOGD(" <<< RECV: Multiline data detected:  " + (string)dataLineCount);
            }

            // Xử lý tiếp với positions[] nếu cần
            if (isDataParsed == true && cmd != eCMD_UNKNOWN)
            {
                LOGD(" <<< RECV: cmdID=" + IntegerToString(cmd) + ", positions count=" + IntegerToString(ArraySize(positions)));

                // không process nếu data không hợp lệ.
                if (Terminal::CheckPositionsValidation(positions) == false)
                {
                    return;
                }
                
                iPosition closedPositions[];
                iPosition newPositions[];
                ComparePositions(positions, newPositions, closedPositions);
                if (cmd < eCMD_UNKNOWN)
                {
                    m_pLocalTerminal.OnRemote_PositionChange(cmd, positions, newPositions, closedPositions);
                    UpdateCurrentPositions(positions);
                }
            }
            else if (isDataParsed == false && cmd != eCMD_UNKNOWN)
            {
                LOGE("data is not retreived cmdID=" + IntegerToString(cmd));
            }
            else
            {
                // ignore if there is no data is read
            }
        }
        else
        {
            LOGE("Failed to open file: " + CommonDatacenter::sFILE_INPUT);
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
};