#include "Terminal.mqh"
#include "TerminalApi.mqh"
#include "CommonDatacenter.mqh"
#include "Types.mqh"
#include "Utils.mqh"

class LocalTerminal : public Terminal
{
private:
    Terminal* m_pRemoteTerminal;

    double m_closedVolumeByTP;      // lưu volume đã bị close bằng TP
    double m_closedVolumeBySLSO;    // lưu volume đã bị close bằng SL/SO

    int m_RegisterFileHandle;       // giữ handle của file để tránh việc xóa file.
    bool mIsRegistered;             // flag để theo dõi đã đăng ký thành công với remote terminal hay chưa.

public:
    LocalTerminal()
    {
        m_closedVolumeByTP = 0.0;
        m_closedVolumeBySLSO = 0.0;
        m_pRemoteTerminal = NULL;

        m_RegisterFileHandle = INVALID_HANDLE;
        mIsRegistered = false;
    }
    ~LocalTerminal() {}

    bool GetRegistered()
    {
        return mIsRegistered;
    }

    void init(Terminal* remoteTerminal) 
    {
        // tạo thư mục để chắc chắn thư mục tồn tại
        if (!FolderIsExist(FOLDER_COMMON, FILE_COMMON))
        {
            FolderCreate(FOLDER_COMMON, FILE_COMMON);
        }
    
        // detect broker and output file:
        string server_name = AccountInfoString(ACCOUNT_SERVER);
        string broker_name = AccountInfoString(ACCOUNT_COMPANY);
        string accountName = AccountInfoString(ACCOUNT_NAME);
        StringToLower(server_name);
        LOGD("server_name= [" + server_name + "], broker_name= [" + broker_name + "], accountName= [" + accountName + "]");
        if (broker_name == BROKER_NAME_FPG)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE = eTERMINAL_TYPE_FPG;
            CommonDatacenter::sFILE_OUTPUT = FOLDER_COMMON + "\\" + DATA_EXCHANGE_FPG;
            CommonDatacenter::sFile_REGISTER_FILE = FOLDER_COMMON + "\\" + REGISTER_FPG;
        }
        else if(StringFind(server_name, "exness") >= 0)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE = eTERMINAL_TYPE_EXNESS;
            CommonDatacenter::sFILE_OUTPUT = FOLDER_COMMON + "\\" + DATA_EXCHANGE_EX;
            CommonDatacenter::sFile_REGISTER_FILE = FOLDER_COMMON + "\\" + REGISTER_EX;
        }
        else if(StringFind(server_name, "xmglobal") >= 0)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE = eTERMINAL_TYPE_XM;
            CommonDatacenter::sFILE_OUTPUT = FOLDER_COMMON + "\\" + DATA_EXCHANGE_XM;
            CommonDatacenter::sFile_REGISTER_FILE = FOLDER_COMMON + "\\" + REGISTER_XM;
        }
        else
        {
            LOGE("Unknown broker: " + server_name);
            CommonDatacenter::sFILE_OUTPUT = "";
            CommonDatacenter::sFile_REGISTER_FILE = "";
            CommonDatacenter::sLOCAL_TERMINAL_TYPE = eTERMINAL_TYPE_UNKNOWN;
        }

        // remove existing OUTPUT file
        if(CommonDatacenter::sLOCAL_TERMINAL_TYPE != eTERMINAL_TYPE_UNKNOWN && FileIsExist(CommonDatacenter::sFILE_OUTPUT))
        {
            FileDelete(CommonDatacenter::sFILE_OUTPUT);
        }

        // tạo file register
        int h = FileOpen(CommonDatacenter::sFile_REGISTER_FILE, FILE_WRITE | FILE_TXT | FILE_COMMON);
        if(h != INVALID_HANDLE)
        {
            m_RegisterFileHandle = h;
            FileWrite(m_RegisterFileHandle, "register");
            LOGD("Created register file: " + CommonDatacenter::sFile_REGISTER_FILE);
        }
        else
        {
            LOGE("Failed to create file: " + CommonDatacenter::sFile_REGISTER_FILE);
        }
    }

    void ResetTradingSession(double remoteAliveVolume, double localAliveVolume)
    {
        if (remoteAliveVolume == 0 && localAliveVolume == 0) {
            LOGD("All done, reset variables");
            ResetTradingSession();
            if (m_pRemoteTerminal != NULL) m_pRemoteTerminal.ResetTradingSession();
        }
    }

    void ResetTradingSession()
    {
        m_closedVolumeByTP = 0.0;
        m_closedVolumeBySLSO = 0.0;
    }

    double GetAliveVolume()
    {
        return TerminalAPI::GetTotalAliveVolume();
    }

    void OnRemote_Disconnected()
    {
        LOGD("==== Do Re-Connecting... ====");
        mIsRegistered = false;
        CommonDataCenter::sFILE_INPUT = "";
        mIsRegistered = DoRegister();
    }

    void DoStartConnecting()
    {
        LOGD("==== Do Connecting... ====");
        int cmd = eCMD_ON_CONNECTING;
        string jsonData = "{}";
        SendData(PackageJson(cmd, jsonData));
    }

    void terminate()
    {
        if(CommonDatacenter::sFILE_OUTPUT != "" && FileIsExist(CommonDatacenter::sFILE_OUTPUT, FILE_COMMON))
        {
            LOGD("Deleting output file: " + CommonDatacenter::sFILE_OUTPUT);
            FileDelete(CommonDatacenter::sFILE_OUTPUT, FILE_COMMON);
        }
        if (CommonDatacenter::sFile_REGISTER_FILE != "" && FileIsExist(CommonDatacenter::sFile_REGISTER_FILE, FILE_COMMON))
        {
            LOGD("Deleting register file: " + CommonDatacenter::sFile_REGISTER_FILE);
            FileDelete(CommonDatacenter::sFile_REGISTER_FILE, FILE_COMMON);
        }
    }

    bool DoRegister()
    {
        bool result = false;
        string xm_regis_file = "MT5-EA-local\\" + REGISTER_XM;
        string ex_regis_file = "MT5-EA-local\\" + REGISTER_EX;
        string fpg_regis_file = "MT5-EA-local\\" + REGISTER_FPG;
        bool isXmFileExisted = FileIsExist(xm_regis_file, FILE_COMMON);
        bool isExFileExisted = FileIsExist(ex_regis_file, FILE_COMMON);
        bool isFpgFileExisted = FileIsExist(fpg_regis_file, FILE_COMMON);
        if (isXmFileExisted && isExFileExisted && isFpgFileExisted)
        {
            LOGD("3 registrations files detected => close EA.");
            TerminalAPI::DoCloseEA();
            return false;
        }
        if (CommonDatacenter::sLOCAL_TERMINAL_TYPE == eTERMINAL_TYPE_XM)
        {
            if (isExFileExisted)
            {
                CommonDatacenter::sFILE_INPUT = FOLDER_COMMON + "\\" + DATA_EXCHANGE_EX;
                result = true;
            }
            else if (isFpgFileExisted)
            {
                CommonDatacenter::sFILE_INPUT = FOLDER_COMMON + "\\" + DATA_EXCHANGE_FPG;
                result = true;
            }
            else
            {
                // neither files are not existed -> ignore
            }
        }
        else if (CommonDatacenter::sLOCAL_TERMINAL_TYPE == eTERMINAL_TYPE_EXNESS)
        {
            if (isXmFileExisted)
            {
                CommonDatacenter::sFILE_INPUT = FOLDER_COMMON + "\\" + DATA_EXCHANGE_XM;
                result = true;
            }
            else if (isFpgFileExisted)
            {
                CommonDatacenter::sFILE_INPUT = FOLDER_COMMON + "\\" + DATA_EXCHANGE_FPG;
                result = true;
            }
            else
            {
                // neither files are not existed -> ignore
            }
        }
        else if (CommonDatacenter::sLOCAL_TERMINAL_TYPE == eTERMINAL_TYPE_FPG)
        {
            if (isXmFileExisted)
            {
                CommonDatacenter::sFILE_INPUT = FOLDER_COMMON + "\\" + DATA_EXCHANGE_XM;
                result = true;
            }
            else if (isExFileExisted)
            {
                CommonDatacenter::sFILE_INPUT = FOLDER_COMMON + "\\" + DATA_EXCHANGE_EX;
                result = true;
            }
            else
            {
                // neither files are not existed -> ignore
            }
        }
        else // eTERMINAL_TYPE_UNKNOWN
        {
            // ignore
        }

        if (result)
        {
            LOGD("Registration Detected: xm=" + (string)isXmFileExisted + ", ex=" + (string)isExFileExisted + ", fpg=" + (string)isFpgFileExisted);
            DoStartConnecting();
        }
        return result;
    }

    /**********************************************************************************
    *
    *  send data to the remote terminal
    *
    ***********************************************************************************/
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
    *   command callbacks
    ***********************************************************************************/
public:
    void OnRemote_DoConnecting()
    {
        double localAliveVolume = TerminalAPI::GetTotalAliveVolume();
        LOGD("<<< Remote terminal connecting...");
        string jsonData = "{";
        jsonData += "\"closed_volume_bySLSO\":" + DoubleToString(m_closedVolumeBySLSO) + ",";
        jsonData += "\"alive_volume\":" + DoubleToString(localAliveVolume);
        jsonData += "}";
        SendData(PackageJson(eCMD_ON_CONNECTED, jsonData));
    }
    void OnRemote_Connected(double remoteClosedVolumeBySLSO, double remoteAliveVolume)
    {
        double localAliveVolume = TerminalAPI::GetTotalAliveVolume();
        LOGD("<<< Remote connected: " + 
                "remote[closedBySLSO=" + DoubleToString(remoteClosedVolumeBySLSO) + ", aliveVolume=" + DoubleToString(remoteAliveVolume) + "]" + 
                "local[closedBySLSO=" + DoubleToString(m_closedVolumeBySLSO) + ", closedByTP=" + DoubleToString(m_closedVolumeByTP) + 
                ", aliveVolume=" + DoubleToString(localAliveVolume) + "]");
    }
    void OnRemote_Update(double remoteClosedVolumeBySLSO, double remoteAliveVolume)
    {
        double localAliveVolume = TerminalAPI::GetTotalAliveVolume();
        LOGD("<<< Remote update: " + 
                "remote[closedBySLSO=" + DoubleToString(remoteClosedVolumeBySLSO) + ", aliveVolume=" + DoubleToString(remoteAliveVolume) + "] " + 
                "local[closedBySLSO=" + DoubleToString(m_closedVolumeBySLSO) +  ", closedByTP=" + DoubleToString(m_closedVolumeByTP) + ", aliveVolume=" + DoubleToString(localAliveVolume) + "]");

        ResetTradingSession(remoteAliveVolume, localAliveVolume);
    }
    void DoSendAliveMsg()
    {
        string jsonData = "{}";
        SendData(PackageJson(eCMD_PING_ALIVE, jsonData));
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
    // MQL4 không có MqlTradeTransaction, MqlTradeRequest, MqlTradeResult
    // Cần chuyển đổi logic này sang OnTrade hoặc hàm tương tự phù hợp với MQL4
    void SynUpLocalInfo()
    {
        int positionsCount = TerminalAPI::DoGetPositionCount();
        if (m_currentLocalPositionCount != positionsCount)
        {
            LOGD("Local position count changed. Old: " + IntegerToString(m_currentLocalPositionCount) + ", New: " + IntegerToString(positionsCount));
            m_currentLocalPositionCount = positionsCount;
        }
        iPosition curLocalPositions[];
        TerminalAPI::DoGetAllPosition(curLocalPositions);
        double localAliveVolume = GetTotalVolume(curLocalPositions);
        LOGD("Sync up local info... Local alive volume: " + DoubleToString(localAliveVolume));
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
        ResetTradingSession(remote_aliveVolume, TerminalAPI::GetTotalAliveVolume());
    }
private:
    void OnRemoteEX_SLSO()
    {
        // khi EX stopout -> Ex stopout ở một điểm nên phải cắt XM ngay.
        LOGD("RemoteEX SL/StopOut. Close all local positions.");
        TerminalAPI::DoEndAllPositions();
    }
    void OnRemoteXM_SLSO(double remote_closedVolumeBySLSO, double remote_aliveVolume)
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