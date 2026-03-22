#include "Terminal.mqh"
#include "TerminalApi.mqh"
#include "CommonDatacenter.mqh"
#include "Types.mqh"
#include "Utils.mqh"

class LocalTerminal : public Terminal
{
private:
    // chỉ lưu các lệnh TP và các lệnh close do EA.
    double m_closedVolumeByTP;
    double m_closedVolumeBySLSO;

    Terminal* m_pRemoteTerminal;

public:
    LocalTerminal() 
    : m_closedVolumeByTP(0.0), 
    m_closedVolumeBySLSO(0.0), m_pRemoteTerminal(NULL) {}

    ~LocalTerminal() {}

    void init(Terminal* remoteTerminal) override
    {
        m_pRemoteTerminal = remoteTerminal;
        InitFiles();
        
        // send init data to remote terminal
        EnumCmdId cmd = eCMD_DO_CONNECTING;
        string jsonData = "{}";
        SendData(PackJson(cmd, jsonData));
    }

    void ResetTradingSession(double remoteAliveVolume, double localAliveVolume)
    {
        if (remoteAliveVolume == 0 && localAliveVolume == 0)
        {
            LOGD("All done, reset variables");
            ResetTradingSession();
            m_pRemoteTerminal.ResetTradingSession();
        }
    }
    void ResetTradingSession() override
    {
        m_closedVolumeByTP = 0.0;
        m_closedVolumeBySLSO = 0.0;
    }

    double GetAliveVolume() override
    {
        return GetTotalAliveVolume();
    }

    void DoReConnecting()
    {
        LOGD("==== Do Re-Connecting... ====");
        init(m_pRemoteTerminal);
    }

    void termniate() override
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
    static string PackJson(EnumCmdId cmdId, string jsonData)
    {
        jsonData = "{\"cmd\":" + IntegerToString(cmdId) + ",\"cmd_data\":" + jsonData + "}";
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
    *   SOLUTION 1: start
    *   EA -> OnLocal_OnTradeTransaction_Solution1()
    *   Remote terminal -> OnRemote_PositionChange__Solution1()
    *   Logics:
    *       local change -> send current position data to remote terminal
    *       remote change -> receive data from remote terminal, 
    *                        then compare with current local position to decide which position is changed, 
    *                        then send changed position data to remote terminal
    ***********************************************************************************/
public:
    void OnLocal_OnTradeTransaction_Solution1(const MqlTradeTransaction& trans,
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

                OnLocal_PositionChange_Solution1(eCHANGE_TYPE_OTHER, currPositions);
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
                    OnLocal_PositionChange_Solution1(eCHANGE_TYPE_SL, currPositions);
                }
                else
                {
                    OnLocal_PositionChange_Solution1(eCHANGE_TYPE_OTHER, currPositions);
                }
            }
            else
            {
                LOGD(">>> POSITION CHANGED: " + IntegerToString(entry));
            }
        }
    }
    void OnRemote_PositionChange_Solution1(int cmdId, iPosition &curRemotePositions[], iPosition &newRemotePositions[], iPosition &closedRemotePositions[])
    {
        iPosition curLocalPositions[];
        DoGetAllPosition(curLocalPositions);

        // log new positions for debugging
        string newPostionsStr = "{";
        for(int i = 0; i < ArraySize(newRemotePositions); i++)
        {
            newPostionsStr += ToSimpleString(newRemotePositions[i]) + ";";
        }
        newPostionsStr += "}";
        LOGD("NewPositions[" + IntegerToString(ArraySize(newRemotePositions)) + "]=" + newPostionsStr);

        // log closed positions for debugging
        string closedPostionsStr = "{";
        for(int i = 0; i < ArraySize(closedRemotePositions); i++)        {
            closedPostionsStr += ToSimpleString(closedRemotePositions[i]) + ";";
        }
        closedPostionsStr += "}";
        LOGD("ClosedPositions[" + IntegerToString(ArraySize(closedRemotePositions)) + "]=" + closedPostionsStr);

        // check data validation before processing
        bool isLocalPositionsValid = Terminal::CheckPositionsValidation(curLocalPositions);

        bool isRemoteCurrentPositionsValid = Terminal::CheckPositionsValidation(curRemotePositions);
        bool isRemoteClosedPositionsValid = Terminal::CheckPositionsValidation(closedRemotePositions);
        bool isRemotePositionsValid = isRemoteCurrentPositionsValid && isRemoteClosedPositionsValid;

        if (isLocalPositionsValid == false || isRemotePositionsValid == false)
        {
            LOGE("Invalid positions: STOP processing. [isLocalPositionsValid=" + (string)isLocalPositionsValid + ", isRemoteCurrentPositionsValid=" + (string)isRemoteCurrentPositionsValid + ", isRemoteClosedPositionsValid=" + (string)isRemoteClosedPositionsValid + "]");
            return;
        }

        // prcess remote command
        switch(cmdId)
        {
            case eCMD_ON_UPDATE:
            // case eCMD_ON_INIT:
                // do nothing
                break;
            case eCMD_ON_SLSO:
                OnRemote_StopOut_Solution1(curLocalPositions, curRemotePositions, newRemotePositions, closedRemotePositions);
                break;
            default:
                LOGD("unexpected cmdID: " + IntegerToString(cmdId));
        }
    }
private:
    void OnLocal_PositionChange_Solution1(EnumChangeType chagne_type, iPosition& currPositions[])
    {
        EnumCmdId cmd_id = eCMD_UNKNOWN;
        switch(chagne_type)
        {
            case eCHANGE_TYPE_SL:
                cmd_id = eCMD_ON_SLSO;
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
    void OnRemote_StopOut_Solution1(iPosition &curLocalPositions[], iPosition &curRemotePositions[], iPosition &newRemotePositions[], iPosition &closedRemotePositions[])
    {
        double newRemmoteVolume = GetTotalVolume(newRemotePositions);
        double closedRemoteVolume = GetTotalVolume(closedRemotePositions);
        double currentRemoteVolume = GetTotalVolume(curRemotePositions);
        if (newRemmoteVolume > 0)
        {
            LOGD("Abnormal case: newRemmoteVolume(" + (string)newRemmoteVolume + ") > 0 when stop out happens" );
        }

        // không process nếu data không hợp lệ.
        if (Terminal::CheckPositionsValidation(curLocalPositions) == false)
        {
            return;
        }

        double localVolume = GetTotalVolume(curLocalPositions);
        LOGD(StringFormat("localVolume=%f | RemoteVolume=%f, newRemmoteVolume=%f, closedRemoteVolume=%f", localVolume, currentRemoteVolume, newRemmoteVolume, closedRemoteVolume));

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
    /*---------  SOLUTION 1: end ---------*/

    /**********************************************************************************
    *   command callbacks
    ***********************************************************************************/
public:
    void OnRemote_DoConnecting()
    {
        double localAliveVolume = GetTotalAliveVolume();
        LOGD("<<< Remote terminal connecting...");
        string jsonData = "{";
        jsonData += "\"closed_volume_bySLSO\":" + DoubleToString(m_closedVolumeBySLSO) + ",";
        jsonData += "\"alive_volume\":" + DoubleToString(localAliveVolume);
        jsonData += "}";
        SendData(PackJson(eCMD_ON_CONNECTED, jsonData));
    }
    void OnRemote_Connected(double remoteClosedVolumeBySLSO, double remoteAliveVolume)
    {
        double localAliveVolume = GetTotalAliveVolume();
        LOGD("<<< Remote connected: " + 
                "remote[closedBySLSO=" + DoubleToString(remoteClosedVolumeBySLSO) + ", aliveVolume=" + DoubleToString(remoteAliveVolume) + "]" + 
                "local[closedBySLSO=" + DoubleToString(m_closedVolumeBySLSO) + ", closedByTP=" + DoubleToString(m_closedVolumeByTP) + 
                ", aliveVolume=" + DoubleToString(localAliveVolume) + "]");
    }
    void OnRemote_Update(double remoteClosedVolumeBySLSO, double remoteAliveVolume)
    {
        double localAliveVolume = GetTotalAliveVolume();
        LOGD("<<< Remote update: " + 
                "remote[closedBySLSO=" + DoubleToString(remoteClosedVolumeBySLSO) + ", aliveVolume=" + DoubleToString(remoteAliveVolume) + "] " + 
                "local[closedBySLSO=" + DoubleToString(m_closedVolumeBySLSO) +  ", closedByTP=" + DoubleToString(m_closedVolumeByTP) + ", aliveVolume=" + DoubleToString(localAliveVolume) + "]");

        ResetTradingSession(remoteAliveVolume, localAliveVolume);
    }
    void DoSendAliveMsg()
    {
        string jsonData = "{}";
        SendData(PackJson(eCMD_PING_ALIVE, jsonData));
    }
    /**********************************************************************************
    *   SOLUTION 2: start
    *   logic:
    *       local change -> do nothing
    *       local SL/SO  -> update m_closedVolumeByTP, send trigger to remote.
    *       local TP     -> update m_closedVolumeByTP.
    *       remote SL/SO -> receive trigger from remote, 
    *                       then get current local position, 
    *                       compare with current remote position to find out 
    *                       which position is closed by SL/SO, 
    *                       then close the same position locally if it's not closed yet.
    *
    ***********************************************************************************/
public:
    void OnLocal_OnTradeTransaction_Solution2(const MqlTradeTransaction& trans,
                            const MqlTradeRequest& request,
                            const MqlTradeResult& result)
    {
        LOGD("TRANS: " + EnumToString(trans.type));
        if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
        {
            if(!HistoryDealSelect(trans.deal))
            {
                return;
            }
            long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            bool needSentUpdate = false;
            double local_aliveVolume = GetTotalAliveVolume();
            if(entry == DEAL_ENTRY_IN)
            {
                needSentUpdate = true;
                LOGD(">>> POSITION OPENED: " + (string)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID));
            }
            else if(entry == DEAL_ENTRY_OUT)
            {
                needSentUpdate = true;
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


                if (info.close_reason == ENUM_DEAL_REASON::DEAL_REASON_TP)
                {
                    // lưu lại thông tin các lệnh bị đóng do TP
                    // để check khi remote SL/SO.
                    m_closedVolumeByTP += info.volume;
                }
                else if (info.close_reason == ENUM_DEAL_REASON::DEAL_REASON_SL
                        || info.close_reason == ENUM_DEAL_REASON::DEAL_REASON_SO)
                {
                    // lưu lại thông tin các lệnh bị đóng do SL/SO
                    // để check khi remote SL/SO
                    m_closedVolumeBySLSO += info.volume;

                    // send data to remote:
                    EnumCmdId cmd = eCMD_ON_SLSO;
                    string jsonData = "{";
                    jsonData += "\"closed_volume_bySLSO\":" + DoubleToString(m_closedVolumeBySLSO) + ",";
                    jsonData += "\"alive_volume\":" + DoubleToString(local_aliveVolume);
                    jsonData += "}";
                    SendData(PackJson(cmd, jsonData));
                    needSentUpdate = false; // đã gửi update trong case SL/SO, nên set lại flag để tránh gửi thêm 1 lần nữa ở phần cuối.
                }
            }
            else
            {
                LOGD(">>> POSITION CHANGED: " + IntegerToString(entry));
            }

            if (needSentUpdate)
            {
                EnumCmdId cmd = eCMD_ON_UPDATE;
                string jsonData = "{";
                jsonData += "\"closed_volume_bySLSO\":" + DoubleToString(m_closedVolumeBySLSO) + ",";
                jsonData += "\"alive_volume\":" + DoubleToString(local_aliveVolume);
                jsonData += "}";
                SendData(PackJson(cmd, jsonData));
            }
            ResetTradingSession(m_pRemoteTerminal.GetAliveVolume(), local_aliveVolume);
        }
    }
    // callback cho remote terminal khi nhận được trigger SL/SO từ remote
    void OnRemote_SLSO(double remote_closedVolumeBySLSO, double remote_aliveVolume)
    {
        LOGD("<<< Remote SL/StopOut received: remote[closedBySLSO=" + DoubleToString(remote_closedVolumeBySLSO) + ", aliveVolume=" + DoubleToString(remote_aliveVolume) + "]");
        switch(CommonDatacenter::sLOCAL_TERMINAL_TYPE)
        {
            case eTERMINAL_TYPE_EXNESS:
                OnRemoteXM_SLSO(remote_closedVolumeBySLSO, remote_aliveVolume);
                break;
            case eTERMINAL_TYPE_XM:
                OnRemoteEX_SLSO();
                break;
            default:
                LOGE("Unknown terminal type: " + EnumToString(CommonDatacenter::sLOCAL_TERMINAL_TYPE));
        }
        ResetTradingSession(remote_aliveVolume, GetTotalAliveVolume());
    }
private:
    void OnRemoteEX_SLSO()
    {
        // khi EX stopout -> Ex stopout ở một điểm nên phải cắt XM ngay.
        LOGD("RemoteEX SL/StopOut. Close all local positions.");
        DoEndAllPositions();
    }
    void OnRemoteXM_SLSO(double remote_closedVolumeBySLSO, double remote_aliveVolume)
    {
        iPosition curLocalPositions[];
        DoGetAllPosition(curLocalPositions);
        double local_aliveVolume = GetTotalVolume(curLocalPositions);
        LOGD("RemoteXM SL/StopOut. Remote[closedBySLSO=" + DoubleToString(remote_closedVolumeBySLSO) + ", aliveVolume=" + DoubleToString(remote_aliveVolume) + "] "
                + "Local[closedByTP=" + DoubleToString(m_closedVolumeByTP) + ", aliveVolume=" + DoubleToString(local_aliveVolume) + "]");
        
        if (remote_aliveVolume == 0 && local_aliveVolume > 0)
        {
            LOGD("Remote volume is 0 but local still has open positions -> Close all");
            DoEndAllPositions();
        }
        else if (remote_aliveVolume > 0)
        {
            // đóng thêm số volme cần thiết để closed volume 2 bên bằng nhau
            double volumeDiff = remote_closedVolumeBySLSO - m_closedVolumeByTP;
            while (volumeDiff > 0 && ArraySize(curLocalPositions) > 0)
            {
                // tìm position có volume lớn nhất để cắt.
                int cutIdx = -1;
                double cutVolume = 0;
                bool isPartialCut = false;
                int size = ArraySize(curLocalPositions);
                for (int i = 0; i < size; i++)
                {
                    if (curLocalPositions[i].volume > cutVolume)
                    {
                        cutVolume = curLocalPositions[i].volume;
                        cutIdx = i;
                    }
                }
                if (cutIdx != -1 && cutVolume > volumeDiff)
                {
                    cutVolume = volumeDiff;
                    isPartialCut = true;
                }
                if (cutIdx >= 0)
                {
                    bool res = false;
                    if (isPartialCut)
                    {
                        res = DoClosePartialPosition(curLocalPositions[cutIdx].position_ticket, cutVolume);
                    }
                    else
                    {
                        res = DoClosePosition(curLocalPositions[cutIdx].position_ticket);
                    }
                    if (res == true)
                    {
                        LOGD("---> Closed position by tool: " + IntegerToString(curLocalPositions[cutIdx].position_ticket) + " | cutVolume: " + DoubleToString(cutVolume) + " | isPartialCut: " + (string)isPartialCut);
                        
                        // remove closed position from local array to avoid close it again in next loop
                        if (isPartialCut)
                        {
                            curLocalPositions[cutIdx].volume -= cutVolume;
                        }
                        else
                        {
                            for(int i = cutIdx; i < size - 1; i++)
                            {
                                curLocalPositions[i] = curLocalPositions[i + 1];
                            }
                            ArrayResize(curLocalPositions, size - 1);
                        }

                        // giảm đi phần volude đã đóng
                        volumeDiff -= cutVolume;

                        // thêm cutVolume vào m_closedVolumeByTP để theo dõi tổng 
                        // volume đã đóng do TP
                        m_closedVolumeByTP += cutVolume;
                    }
                    else
                    {
                        LOGE("---> Failed to close position by tool: ticket=" + IntegerToString(curLocalPositions[cutIdx].position_ticket) + " | Error: " + IntegerToString(GetLastError()));
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
    }
    /*---------  SOLUTION 2: end ---------*/

};