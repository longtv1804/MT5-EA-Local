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
    int mOutputFileId;

    ulong mLastReadPosition;

    /**********************************************************************************
    *
    *  Get / Set functions
    *
    ***********************************************************************************/
public:
    int GetId()
    {
        return mOutputFileId;
    }

    /**********************************************************************************
    *
    *  init/terminate function
    *
    ***********************************************************************************/
public:
    CPT_InOutManager()
    {
        mInputFile = "";
        mOutputFile = "";
        mOutputFileId = 0;
    }
    bool InitFilesPath()
    {
        if (mInputFile != "" && mOutputFile != "")
        {
            LOGE("FilePaths are initialized");
            return false;
        }
        int i = 0, size = 0;
        bool isFileExisted = false;
        if (CommonDatacenter::s_copyTradeMode == eCPT_MODE_SERVER)
        {
            // output file:
            mOutputFile = CPT_SERVER_OUTPUT_FILE_PATH;
            isFileExisted = FileIsExist(mOutputFile, FILE_COMMON);
            if (isFileExisted == true)
            {
                TerminalAPI::DoShowMessagePopup("SERVER is already existed, close EA!!!");
                // trường hợp SERVER đã tồn tại: 
                // gán lại mOutputFile để tránh remove file khi terminate
                mOutputFile = "";
                TerminalAPI::DoCloseEA();
                return false;
            }

            // no need detect input file path
            mInputFile = mOutputFile;
        }
        else if (CommonDatacenter::s_copyTradeMode == eCPT_MODE_CLIENT)
        {
            // output file: thử 5 lần randome ID
            string outputFilePath = "";
            for (i = 0; i < 5; i++)
            {
                int id = MathRand();
                outputFilePath = CPT_CLIENT_OUTPUT_FILE_HEADER + (string)id + ".dat";
                isFileExisted = FileIsExist(outputFilePath, FILE_COMMON);
                if (isFileExisted == false)
                {
                    mOutputFileId = id;
                    break;
                }
            }
            if (outputFilePath == "")
            {
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
        if(mOutputFile != "" && FileIsExist(mOutputFile, FILE_COMMON))
        {
            FileDelete(mOutputFile, FILE_COMMON);
            LOGD("Removed output file: " + mOutputFile);
        }
    }

public:
    // với server thì init ngay khi khởi tạo
    // với client thì init sau khi detect server file
    bool Init()
    {  
        // tạo thư mục để chắc chắn thư mục tồn tại
        if (!FileIsExist(FOLDER_EA_DIR, FILE_COMMON))
        {
            FolderCreate(FOLDER_EA_DIR, FILE_COMMON);
        }

        // init input và output file paths
        bool res = true;
        if (mInputFile == "" || mOutputFile == "")
        {
            res = InitFilesPath();
        }
        if (res)
        {
            res = CreateOutputFile();
        }
        if (!res)
        {
            LOGE("ERROR when init filepath or CreateOutputFile");
        }
        return res;
    }

    // server: terminate khi close EA
    // client: terminate khi mà mất kết nối server hoặc close EA
    void Terminate()
    {
        LOGD("terminate InOutManager...");
        RemoveOutputFile();
        mLastReadPosition = 0;
    }

    /**********************************************************************************
    *
    *  send data to the remote terminal
    *
    ***********************************************************************************/
public:
    void SendData(string jsonData)
    {
        if (mOutputFile == "")
        {
            LOGE("InputFile is not detected");
            return;
        }

        int handle = FileOpen(mOutputFile, FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_ANSI|FILE_COMMON);
        if(handle != INVALID_HANDLE)
        {
            FileSeek(handle, 0, SEEK_END);
            FileWrite(handle, jsonData);
            FileClose(handle);
            LOGD(">>> SEND: " + jsonData);
        }
        else
        {
            LOGE("Failed to open file: " + mOutputFile);
        }
    }
    /***********************************************************************
    *
    *   Connection functions.
    *
    ***********************************************************************/
public:
    int GetClientList(int &clientIdList[])
    {
        string path_pattern = CPT_CLIENT_OUTPUT_FILE_HEADER + "*.dat";

        long handle;
        string file;
        int attr = FILE_COMMON;

        ArrayResize(clientIdList, 0);

        handle = FileFindFirst(path_pattern, file, attr);

        if(handle == INVALID_HANDLE)
        {
            return 0;
        }

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

    /***********************************************************************
    *
    *   for CPT_ClientTerminal
    *
    ***********************************************************************/
public:
    void SeekToEndInputFile()
    {
        int handle = FileOpen(mInputFile, FILE_READ|FILE_TXT|FILE_SHARE_WRITE|FILE_ANSI|FILE_COMMON);
        if(handle != INVALID_HANDLE)
        {
            // Check file size before seeking
            // nếu vị trí đọc cũ lớn hơn file, thì reset về 0 và đọc lại từ đầu.
            FileSeek(handle, 0, SEEK_END);
            mLastReadPosition = FileTell(handle);
            FileClose(handle);
        }
        else
        {
           LOGE("Can not open file (" + mInputFile + ")"); 
        }
    }

    // return true if the file is existed
    bool CheckInputFile()
    {
        if (mInputFile == "")
        {
            return false;
        }
        bool isInputExisted = FileIsExist(mInputFile, FILE_COMMON);
        if (isInputExisted == false)
        {
            return false;
        }
        return true;
    }

    // fetch data from input file
    int PollData(string &cmdList[])
    {
        bool isInputExisted = FileIsExist(mInputFile, FILE_COMMON);
        if (isInputExisted == false)
        {
            return 0;
        }

        int dataLineCount = 0;
        ArrayResize(cmdList, dataLineCount);

        int handle = FileOpen(mInputFile, FILE_READ|FILE_TXT|FILE_SHARE_WRITE|FILE_ANSI|FILE_COMMON);
        if(handle != INVALID_HANDLE)
        {
            FileSeek(handle, mLastReadPosition, SEEK_SET);
            while(!FileIsEnding(handle))
            {
                string line = FileReadString(handle);
                if(StringLen(line) > 0)
                {
                    
                    ArrayResize(cmdList, dataLineCount + 1);
                    cmdList[dataLineCount] = line;
                    dataLineCount += 1;
                }
            }
            mLastReadPosition = FileTell(handle);
            FileClose(handle);
        }
        else
        {
           LOGE("Can not open file (" + mInputFile + ")"); 
        }
        return dataLineCount;
    }
};