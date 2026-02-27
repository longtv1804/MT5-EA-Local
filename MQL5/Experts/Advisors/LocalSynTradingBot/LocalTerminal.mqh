#include "Terminal.mqh"
#include "TerminalApi.mqh"
#include "CommonDatacenter.mqh"
#include "Types.mqh"
#include "Utils.mqh"

class LocalTerminal
{
public:
    LocalTerminal() {}
    ~LocalTerminal() {}

    void init()
    {
        InitFiles();
        
        // send init data to remote terminal
        EnumCmdId cmd = eCMD_ON_INIT;
        iPosition currPositions[];
        DoGetAllPosition(currPositions);
        string jsonData = PackJson(cmd, currPositions);
        SendData(jsonData);
    }

    void termniate()
    {
        // xóa file output
        if(CommonDatacenter::sFILE_OUTPUT != "" && FileIsExist(CommonDatacenter::sFILE_OUTPUT, FILE_COMMON))
        {
            LOGD("Deleting output file: " + CommonDatacenter::sFILE_OUTPUT);
            FileDelete(CommonDatacenter::sFILE_OUTPUT, FILE_COMMON);
        }
    }

    void InitFiles()
    {
        string server_name = AccountInfoString(ACCOUNT_SERVER);
        string broker_name = AccountInfoString(ACCOUNT_COMPANY);
        string accountName = AccountInfoString(ACCOUNT_NAME);
        StringToLower(server_name);

        string folder = "MT5-EA-local\\";
        string xm_file = folder + XM_TO_EXNESS_FILE;
        string ex_file = folder + EXNESS_TO_XM_FILE;

        LOGD("server_name= " + server_name + ", broker_name= " + broker_name + ", accountName= " + accountName);
        if(StringFind(server_name, "exness") >= 0)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE = eTERMINAL_TYPE_EXNESS;
            CommonDatacenter::sFILE_OUTPUT = ex_file;
            CommonDatacenter::sFILE_INPUT = xm_file;
        }
        else if(StringFind(server_name, "xmglobal") >= 0)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE = eTERMINAL_TYPE_XM;
            CommonDatacenter::sFILE_OUTPUT = xm_file;
            CommonDatacenter::sFILE_INPUT = ex_file;
        }
        else
        {
            LOGE("Unknown broker: " + server_name);
            CommonDatacenter::sFILE_OUTPUT = "";
            CommonDatacenter::sFILE_INPUT = "";
            CommonDatacenter::sLOCAL_TERMINAL_TYPE = eTERMINAL_TYPE_UNKNOWN;
        }
        // remove existing OUTPUT file
        if(CommonDatacenter::sLOCAL_TERMINAL_TYPE != eTERMINAL_TYPE_UNKNOWN && FileIsExist(CommonDatacenter::sFILE_OUTPUT))
        {
            FileDelete(CommonDatacenter::sFILE_OUTPUT);
        }

        // re-create OUTPUT file to make sure it's empty and can be opened for writing
        int h = FileOpen(CommonDatacenter::sFILE_OUTPUT, FILE_WRITE | FILE_TXT | FILE_COMMON);
        if(h != INVALID_HANDLE)
        {
            FileClose(h);
        }
        else
        {
            LOGE("Failed to create file: " + CommonDatacenter::sFILE_OUTPUT);
        }

        LOGD("sLOCAL_TERMINAL_TYPE: " + EnumToString(CommonDatacenter::sLOCAL_TERMINAL_TYPE));
        LOGD("CommonDatacenter::sFILE_OUTPUT: " + CommonDatacenter::sFILE_OUTPUT);
        LOGD("CommonDatacenter::sFILE_INPUT: " + CommonDatacenter::sFILE_INPUT);
    }

    /**********************************************************************************
    *
    *  send data to the remote terminal
    *
    ***********************************************************************************/
    static string PackJson(EnumCmdId cmdId, iPosition &arr[])
    {
        string jsonData = "{";
        jsonData += "\"cmd\":" + IntegerToString(cmdId) + ",";
        jsonData += "\"curent_positions\":[";
        for(int i = 0; i < ArraySize(arr); i++)
        {
            jsonData += ToJson(arr[i]);
            if(i < ArraySize(arr) - 1)
                jsonData += ",";
        }
        jsonData += "]}";
        return jsonData;
    }
    void SendData(string jsonData)
    {
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

    /**********************************************************************************
    *
    *  OnLocal fucntions
    *        trigger when there some thing change in the local terminal
    *
    ***********************************************************************************/
    void OnLocal_OnTradeTransaction(const MqlTradeTransaction& trans,
                            const MqlTradeRequest& request,
                            const MqlTradeResult& result)
    {
        LOGD("TRANS: " + EnumToString(trans.type));
        if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
        {
            LOGD(ToString(trans));
            LOGD(ToString(request));
            LOGD(ToString(result));
            
            iPosition currPositions[];
            DoGetAllPosition(currPositions);
            if(ArraySize(currPositions) == 0)
            {
                LOGD("NOW Position: No opened positions");
            }
            else
            {
                for(int i = 0; i < ArraySize(currPositions); i++)
                {
                    LOGD("NOW Position[" + IntegerToString(i) + "] " + ToString(currPositions[i]));
                }
            }

            if(!HistoryDealSelect(trans.deal))
            {
                return;
            }

            long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

            if(entry == DEAL_ENTRY_IN)
            {
                long position_ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
                int size = ArraySize(currPositions);
                int idx = 0;
                for(idx = 0; idx < size; idx++)
                {
                    if(currPositions[idx].position_ticket == position_ticket)
                    {
                        break;
                    }
                }
                if (idx == size)
                {
                    LOGE("can not find out new ticket: " + IntegerToString(position_ticket));
                }
                else
                {
                    LOGD(">>> POSITION OPENED: " + ToString(currPositions[idx]));
                }

                OnLocal_PositionChange(eCHANGE_TYPE_OTHER, currPositions);
            }
            else if(entry == DEAL_ENTRY_OUT)
            {
                iPosition info;
                ZeroMemory(info);

                info.position_ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
                info.deal_ticket     = trans.deal;
                info.symbol          = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
                info.volume          = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
                info.price_close     = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
                info.time_close      = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
                info.status          = ePOSITION_STATUS_CLOSED;
                info.close_reason    = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);
                LOGD(">>> POSITION CLOSED: " + ToString(info));

                // chỉ noti SL khi lệnh tự động đóng do SL hoặc SO
                // các lý do khác đều chỉ noti chung 1 kiểu: lệnh đóng bằng tay, đóng do TP, đóng do hết hạn,... đều noti chung 1 kiểu: OTHER
                if (info.close_reason == ENUM_DEAL_REASON::DEAL_REASON_SL
                    || info.close_reason == ENUM_DEAL_REASON::DEAL_REASON_SO)
                {
                    OnLocal_PositionChange(eCHANGE_TYPE_SL, currPositions);
                }
                else
                {
                    OnLocal_PositionChange(eCHANGE_TYPE_OTHER, currPositions);
                }
            }
            else
            {
                LOGD(">>> POSITION CHANGED: " + IntegerToString(entry));
            }
        }
    }

    void OnLocal_PositionChange(EnumChangeType chagne_type, iPosition& currPositions[])
    {
        EnumCmdId cmd_id = eCMD_UNKNOWN;
        switch(chagne_type)
        {
            case eCHANGE_TYPE_SL:
                cmd_id = eCMD_ON_SL;
                break;
            case eCHANGE_TYPE_OTHER:
                cmd_id = eCMD_ON_UPDATE;
                break;
            default:
                LOGE("Unknown change type");
        }
        if(cmd_id != eCMD_UNKNOWN)
        {
            string jsonData = PackJson(cmd_id, currPositions);
            SendData(jsonData);
        }
    }

    /**********************************************************************************
    *
    *  OnRemote fucntions
    *        trigger when remote data is received
    *
    ***********************************************************************************/
    void OnRemote_PositionChange(int cmdId, iPosition &currentPositions[], iPosition &newPositions[], iPosition &closedPositions[])
    {
        // log new positions for debugging
        string newPostionsStr = "{";
        for(int i = 0; i < ArraySize(newPositions); i++)
        {
            newPostionsStr += ToSimpleString(newPositions[i]) + ";";
        }
        newPostionsStr += "}";
        LOGD("NewPositions[" + IntegerToString(ArraySize(newPositions)) + "]=" + newPostionsStr);

        // log closed positions for debugging
        string closedPostionsStr = "{";
        for(int i = 0; i < ArraySize(closedPositions); i++)        {
            closedPostionsStr += ToSimpleString(closedPositions[i]) + ";";
        }
        closedPostionsStr += "}";
        LOGD("ClosedPositions[" + IntegerToString(ArraySize(closedPositions)) + "]=" + closedPostionsStr);

        switch(cmdId)
        {
            case eCMD_ON_UPDATE:
            case eCMD_ON_INIT:
                // do nothing
                break;
            case eCMD_ON_SL:
                OnRemote_StopOut(currentPositions, newPositions, closedPositions);
                break;
            default:
                LOGD("unexpected cmdID: " + IntegerToString(cmdId));
        }
    }

private:
    void OnRemote_StopOut(iPosition &curPositions[], iPosition &newPositions[], iPosition &closedPositions[])
    {
        ulong newRemmoteVolume = GetTotalVolume(newPositions);
        ulong closedRemoteVolume = GetTotalVolume(closedPositions);
        ulong currentRemoteVolume = GetTotalVolume(curPositions);
        if (newRemmoteVolume > 0)
        {
            LOGD("Abnormal case: newRemmoteVolume(" + (string)newRemmoteVolume + ") > 0 when stop out happens" );
        }

        iPosition curLocalPositions[];
        DoGetAllPosition(curLocalPositions);
        // không process nếu data không hợp lệ.
        if (Terminal::CheckPositionsValidation(curLocalPositions) == false)
        {
            return;
        }

        ulong localVolume = GetTotalVolume(curLocalPositions);
        LOGD(StringFormat("localVolume=%d | RemoteVolume=%d, newRemmoteVolume=%d, closedRemoteVolume=%d", localVolume, currentRemoteVolume, newRemmoteVolume, closedRemoteVolume));

        while (localVolume > currentRemoteVolume)
        {
            // find the highest volume position to cut first
            int cutIdx = -1;
            double cutVolume = 0;
            int size = ArraySize(curLocalPositions);
            for (int i = 0; i < size; i++)
            {
                if (curLocalPositions[i].volume > cutVolume)
                {
                    cutVolume = curLocalPositions[i].volume;
                    cutIdx = i;
                }
            }
            if (cutIdx >= 0)
            {
                bool res = DoClosePosition(curLocalPositions[cutIdx].position_ticket);
                if (res == true)
                {
                    LOGD("---> Closed position by ticket: " + IntegerToString(curLocalPositions[cutIdx].position_ticket));
                    
                    // remove closed position from local array to avoid close it again in next loop
                    for(int i = cutIdx; i < size - 1; i++)
                    {
                        curLocalPositions[i] = curLocalPositions[i + 1];
                    }
                    ArrayResize(curLocalPositions, size - 1);

                    // giảm đi phần volude đã đóng
                    localVolume -= cutVolume;
                }
                else
                {
                    LOGE("---> Failed to close position with ticket: " + IntegerToString(curLocalPositions[cutIdx].position_ticket) + " | Error: " + IntegerToString(GetLastError()));
                    break;
                }
            }
            else
            {
                LOGE("Can not find position to cut");
                break;
            }
        }
    }
};