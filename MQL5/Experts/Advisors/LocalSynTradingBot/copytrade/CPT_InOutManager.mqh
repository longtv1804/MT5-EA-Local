#include "../common/Terminal.mqh"
#include "../common/CommonDatacenter.mqh"
#include "../common/TerminalApi.mqh"
#include "../common/Types.mqh"
#include "../common/Utils.mqh"

class CPT_InOutManager
{
private:
	string mInputFile;
	string mOutputFile;

    ulong mLastReadPosition;
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
        }
    }

    /**********************************************************************************
    *
    *  init/terminate function
    *
    ***********************************************************************************/
private:
    bool InitFilesPath()
    {
        if (CommonDatacenter::s_copyTradeMode == eCPT_MODE_SERVER)
        {
            // output file:
            mOutputFile = CPT_SERVER_OUTPUT_FILE_PATH;
            bool isFileExisted = FileIsExist(mOutputFile, FILE_COMMON);
            if (isFileExisted == false)
            {
                LOGD("SERVER is already existed!!!");
                TerminalAPI::DoShowMessagePopup("SERVER is already existed, close EA!!!");
                TerminalAPI::DoCloseEA();
                return false;
            }

            // no need detect input file path
            mInputFile = "";
        }
        else if (CommonDatacenter::s_copyTradeMode == eCPT_MODE_CLIENT)
        {
            // output file: thử 3 lần randome ID
            string outputFilePath = "";
            for (int i = 0; i < 3; i++)
            {
                int id = MathRand();
                outputFilePath = CPT_CLIENT_OUTPUT_FILE_HEADER + (string)id + ".dat";
                bool isFileExisted = FileIsExist(outputFilePath, FILE_COMMON);
                if (isFileExisted == false)
                {
                    break;
                }
            }
            if (outputFilePath == "")
            {
                LOGD("try 3 time but can not get client ID, close EA!!!");
                TerminalAPI::DoShowMessagePopup("try 3 time but can not get client ID, close EA!!!");
                TerminalAPI::DoCloseEA();
                return false;
            }
            mOutputFile = outputFilePath;

            // input file:
            mInputFile = CPT_SERVER_OUTPUT_FILE_PATH;
        }
        else
        {
            LOGD("Unknow copy trade mode, close EA!!!");
            TerminalAPI::DoShowMessagePopup("Unknow copy trade mode, close EA!!!");
            TerminalAPI::DoCloseEA();
            return false;
        }
        LOGE("CPT mode:" + ToString(CommonDatacenter::s_copyTradeMode) + " output:" + mOutputFile + " input:" + mInputFile);
        return true;
    }

    bool CreateOutputFile()
    {
        if (mOutputFile == "")
        {
            return false;
        }
        int h = FileOpen(mOutputFile, FILE_WRITE | FILE_TXT | FILE_COMMON);
        if(h != INVALID_HANDLE)
        {
            FileClose(h);
            LOGD("Created output file: " + mOutputFile);
        }
        else
        {
            LOGE("Failed to create file: " + mOutputFile);
            return false;
        }
        return true;
    }

    void RemoveOutputFile()
    {
        if(mOutputFile == "" && FileIsExist(mOutputFile, FILE_COMMON))
        {
            FileDelete(CommonDatacenter::sFILE_OUTPUT, FILE_COMMON);
            LOGD("Removed output file: " + CommonDatacenter::sFILE_OUTPUT);
        }
    }

public:
    void init()
    {  
        // tạo thư mục để chắc chắn thư mục tồn tại
        if (!FileIsExist(FOLDER_EA_DIR, FILE_COMMON))
        {
            FolderCreate(FOLDER_EA_DIR, FILE_COMMON);
        }

        // init input và output file paths
        bool res = InitFilesPath();
        if (res)
        {
            res = CreateOutputFile();
            if (res)
            {
                if (CommonDatacenter::s_copyTradeMode == eCPT_MODE_SERVER)
                {
                    SetConnectionState(eREMOTE_STATE_CONNECTED);
                }
                else if (CommonDatacenter::s_copyTradeMode == eCPT_MODE_CLIENT)
                {
                    SetConnectionState(eREMOTE_STATE_WAIT_INPUT);
                }
                else
                {
                    // vì đã init file thành công nên case else này sẽ ko vào
                }
            }
        }
    }
    void Terminate()
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
public:
    // for CPT_ServerTerminal
    int GetClientList(int &clientIdList[])
    {
        string path_pattern = CPT_CLIENT_OUTPUT_FILE_HEADER + "*.dat";

        long handle;
        string file;
        int attr = 0;

        ArrayResize(clientIdList, 0);

        handle = FileFindFirst(path_pattern, file, attr);

        if(handle == INVALID_HANDLE)
            return 0;

        do
        {
            // file = CPT_client_123.dat
            string name = file;

            // remove prefix
            string prefix = "CPT_client_";
            string suffix = ".dat";

            if(StringFind(name, prefix) == 0 && StringFind(name, suffix) > 0)
            {
                string id_str = StringSubstr(
                    name,
                    StringLen(prefix),
                    StringLen(name) - StringLen(prefix) - StringLen(suffix)
                );

                int id = (int)StringToInteger(id_str);

                int size = ArraySize(clientIdList);
                ArrayResize(clientIdList, size + 1);
                clientIdList[size] = id;
            }
        }
        while(FileFindNext(handle, file));

        FileFindClose(handle);
        return ArraySize(clientIdList);
    }

    // for CPT_ClientTerminal
    void PollData(string &cmdList[])
    {

    }
};