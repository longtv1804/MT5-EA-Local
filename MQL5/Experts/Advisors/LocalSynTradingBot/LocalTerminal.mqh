#include "Terminal.mqh"
#include "InOutController.mqh"
#include "TerminalApi.mqh"
#include "CommonDatacenter.mqh"
#include "Types.mqh"
#include "Utils.mqh"

class LocalTerminal : public Terminal
{
private:
    Terminal *m_pRemoteTerminal;
    InOutController *m_pInOutController;

    double m_closedVolumeByTP;      // lưu volume đã bị close bằng TP
    double m_closedVolumeBySLSO;    // lưu volume đã bị close bằng SL/SO

/**********************************************************************************
*
*  init/terminate function
*
***********************************************************************************/
private:
    void DetectBroker()
    {
        string server_name = AccountInfoString(ACCOUNT_SERVER);
        string broker_name = AccountInfoString(ACCOUNT_COMPANY);
        string accountName = AccountInfoString(ACCOUNT_NAME);
        StringToLower(server_name);
        LOGD("server_name=[" + server_name + "], broker_name=[" + broker_name + "], accountName=[" + accountName + "]");
        if (broker_name == BROKER_NAME_FPG)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_FPG;
        }
        else if (broker_name == BROKER_NAME_ULTIMA)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_ULTIMA;
        }
        else if (broker_name == BROKER_NAME_PEPRE)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_PEPRE;
        }
        else if (broker_name == BROKER_NAME_VANTAGE)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_VANTAGE;
        }
        else if(StringFind(server_name, "exness") >= 0)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_EXNESS;
        }
        else if(StringFind(server_name, "xmglobal") >= 0)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_XM;
        }
        else
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_UNKNOWN;
        }
        m_TerminalType = CommonDatacenter::sLOCAL_TERMINAL_TYPE;
    }
public:
    LocalTerminal() : m_pRemoteTerminal(NULL), m_pInOutController(NULL)
    {
        m_closedVolumeByTP = 0.0;
        m_closedVolumeBySLSO = 0.0;
    }

    ~LocalTerminal() {}

    void init(InOutController* inOutController, Terminal* remoteTerminal)
    {
        m_pRemoteTerminal = remoteTerminal;
        m_pInOutController = inOutController;
        DetectBroker();
    }

    void terminate() override
    {
    }

    void ResetTradingSession() override
    {
        m_closedVolumeByTP = 0.0;
        m_closedVolumeBySLSO = 0.0;
    }
    double GetAliveVolume() override
    {
        return TerminalAPI::GetTotalAliveVolume();
    }
    double GetClosedVolumeBySLSO() override
    {
        return m_closedVolumeBySLSO;
    }
/**********************************************************************************
*
*  virtual function
*
***********************************************************************************/
    void OnRemote_Connecting() override
    {
        double localAliveVolume = TerminalAPI::GetTotalAliveVolume();
        LOGD("<<< Remote terminal connecting...");
        string jsonData = "{";
        jsonData += "\"terminal_type\":" + IntegerToString(CommonDatacenter::sLOCAL_TERMINAL_TYPE) + ",";
        jsonData += "\"closed_volume_bySLSO\":" + DoubleToString(m_closedVolumeBySLSO) + ",";
        jsonData += "\"alive_volume\":" + DoubleToString(TerminalAPI::GetTotalAliveVolume());
        jsonData += "}";
        m_pInOutController.SendData(ToJson(eCMD_ON_CONNECTED, jsonData));
    }
    void OnRemote_Connected(EnumTerminalType terminalType, double closedVolumeBySLSO, double alivePositionsVolume) override
    {
    }
    void OnRemote_OnSLSO(double remote_closedVolumeBySLSO, double remote_aliveVolume) override
    {
        LOGD("<<< Remote SL/StopOut received: remote[closedBySLSO=" + DoubleToString(remote_closedVolumeBySLSO) + ", aliveVolume=" + DoubleToString(remote_aliveVolume) + "]");
        switch(m_pRemoteTerminal.GetTerminalType())
        {
            case eTERMINAL_TYPE_EXNESS:
                OnRemoteSLSO_Plan_1(remote_closedVolumeBySLSO, remote_aliveVolume);
                break;
            case eTERMINAL_TYPE_XM:
            case eTERMINAL_TYPE_FPG:
            case eTERMINAL_TYPE_ULTIMA:
            case eTERMINAL_TYPE_PEPRE:
            case eTERMINAL_TYPE_VANTAGE:
                OnRemoteSLSO_Plan_2(remote_closedVolumeBySLSO, remote_aliveVolume);
                break;
            default:
                LOGE("Unknown terminal type: " + EnumToString(CommonDatacenter::sLOCAL_TERMINAL_TYPE));
                OnRemoteSLSO_Plan_2(remote_closedVolumeBySLSO, remote_aliveVolume);
                break;
        }

        // trong trường hợp remote đã về 0 và local cũng về 0.
        // phải reset data để cho lượt sau
        if (remote_aliveVolume == 0 && TerminalAPI::GetTotalAliveVolume() == 0)
        {
            LOGD("All done, reset variables");
            ResetTradingSession();
            m_pRemoteTerminal.ResetTradingSession();
        }
    }
    void OnRemote_Update(double remote_closedVolumeBySLSO, double remote_aliveVolume) override
    {
        LOGD("<<< Remote update received: remote[closedBySLSO=" + DoubleToString(remote_closedVolumeBySLSO) + ", aliveVolume=" + DoubleToString(remote_aliveVolume) + "]");
    }
    void OnRemote_Disconnected() override
    {

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
    void OnLocal_OnTradeTransaction(const MqlTradeTransaction& trans,
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
            double local_aliveVolume = TerminalAPI::GetTotalAliveVolume();
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
                info.symbol          = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
                info.volume          = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
                info.price_close     = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
                info.status          = ePOSITION_STATUS_CLOSED;
                info.close_reason    = ConvertCloseReason((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON));
                LOGD(">>> POSITION CLOSED: " + ToString(info));


                if (info.close_reason == eCLOSE_REASON_TP)
                {
                    // lưu lại thông tin các lệnh bị đóng do TP
                    // để check khi remote SL/SO.
                    m_closedVolumeByTP += info.volume;
                }
                else if (info.close_reason == eCLOSE_REASON_SL
                        || info.close_reason == eCLOSE_REASON_SO)
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
                    m_pInOutController.SendData(ToJson(cmd, jsonData));
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
                m_pInOutController.SendData(ToJson(cmd, jsonData));
            }

            // trong trường hợp remote đã về 0 và local cũng về 0.
            // phải reset data để cho lượt sau
            if (local_aliveVolume == 0 && m_pRemoteTerminal.GetAliveVolume() == 0)
            {
                LOGD("All done, reset variables");
                ResetTradingSession();
                m_pRemoteTerminal.ResetTradingSession();
            }
        }
    }
private:
    // PLAN-1: cắt tất cả khi SL/SO xảy ra ở remote
    void OnRemoteSLSO_Plan_1(double remote_closedVolumeBySLSO, double remote_aliveVolume)
    {
        // khi EX stopout -> Ex stopout ở một điểm nên phải cắt XM ngay.
        LOGD("Remote SL/StopOut. Close all local positions.");
        TerminalAPI::DoEndAllPositions();
    }
    // PLAN-2: cắt một phần nếu remote chỉ SL/SO một phần volume
    void OnRemoteSLSO_Plan_2(double remote_closedVolumeBySLSO, double remote_aliveVolume)
    {
        iPosition curLocalPositions[];
        TerminalAPI::DoGetAllPosition(curLocalPositions);
        double local_aliveVolume = GetTotalVolume(curLocalPositions);
        LOGD("RemoteXM SL/StopOut. Remote[closedBySLSO=" + DoubleToString(remote_closedVolumeBySLSO) + ", aliveVolume=" + DoubleToString(remote_aliveVolume) + "] "
                + "Local[closedByTP=" + DoubleToString(m_closedVolumeByTP) + ", aliveVolume=" + DoubleToString(local_aliveVolume) + "]");
        
        if (remote_aliveVolume == 0 && local_aliveVolume > 0)
        {
            LOGD("Remote volume is 0 but local still has open positions -> Close all");
            TerminalAPI::DoEndAllPositions();
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
                        res = TerminalAPI::DoClosePartialPosition(curLocalPositions[cutIdx].position_ticket, cutVolume);
                    }
                    else
                    {
                        res = TerminalAPI::DoClosePosition(curLocalPositions[cutIdx].position_ticket);
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