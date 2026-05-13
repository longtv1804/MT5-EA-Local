#ifdef __MQL5__
#include <Trade/Trade.mqh>
#endif
#include "../common/JsonBuilder.mqh"
#include "../common/Utils.mqh"
#include "../common/Types.mqh"
#include "../common/Constants.mqh"

class CPT_CopyTradeSession
{
    EnumCopyTradeMode mCptMode;
    int mSessionId;
    double mWeight;
    // lưu giá trị position_ticket của server ở vị trí chẵn 0, 2, 4..., 
    // và ticket đối ứng ở vị trí lẻ 1, 2, 3...
    ulong mTradingMap[];

    static string NormalizeBrokerName(string text)
    {
        // trim đầu/cuối
        StringTrimLeft(text);
        StringTrimRight(text);

        // replace space -> _
        StringReplace(text, " ", "_");

        return text;
    }

    static string GetFilePath()
    {
        string server_name = AccountInfoString(ACCOUNT_SERVER);
        string broker_name = AccountInfoString(ACCOUNT_COMPANY);
        #ifdef __MQL5__
        long acc_id = AccountInfoInteger(ACCOUNT_LOGIN);
        #else
        long acc_id = AccountNumber();
        #endif

        server_name = NormalizeBrokerName(server_name);
        broker_name = NormalizeBrokerName(broker_name);
        return FOLDER_EA_DIR + "\\CPT_DATA\\" + broker_name + "_" + server_name + "_" + (string)acc_id + ".dat";
    }

    static void CreateDataFolder()
    {
        // tạo thư mục để chắc chắn thư mục tồn tại
        if (!FileIsExist(FOLDER_EA_DIR + "\\CPT_DATA\\", FILE_COMMON))
        {
            FolderCreate(FOLDER_EA_DIR + "\\CPT_DATA\\", FILE_COMMON);
        }
    }

    /**********************************************************************************
    *
    *  contructor and get/set function
    *
    ***********************************************************************************/
public:
    CPT_CopyTradeSession() {}
    CPT_CopyTradeSession(EnumCopyTradeMode mode, int id, double weight)
    {
        mCptMode = mode;
        mSessionId = id;
        mWeight = weight;
    }

    void SetSessionId(int id)
    {
        mSessionId = id;
    }

    int GetSessionId() const
    {
        return mSessionId;
    }

    void SetWeight(double weight)
    {
        mWeight = weight;
    }

    double GetWeight() const
    {
        return mWeight;
    }

    void SetMode(EnumCopyTradeMode mode)
    {
        mCptMode = mode;
    }

    EnumCopyTradeMode GetMode() const
    {
        return mCptMode;
    }

    int GetCptPositionNumber() const
    {
        return ArraySize(mTradingMap) / 2;
    }

    void CopyTradingMap(CPT_CopyTradeSession& target)
    {
        int size = ArraySize(mTradingMap);
        for (int i = 0; i < size; i += 2)
        {
            target.AddCopyTradPosition(mTradingMap[i], mTradingMap[i+1]);
        }
    }

    ulong GetClientTicket(ulong server_ticket)
    {
        if (server_ticket == 0)
        {
            LOGE("server_ticket = 0");
            return 0;
        }
        ulong res = 0;
        int size = ArraySize(mTradingMap);
        for (int i = 0; i < size; i += 2)
        {
            if (mTradingMap[i] == server_ticket)
            {
                res = mTradingMap[i + 1];
                break;
            }
        }
        return res;
    }
    ulong GetServerTicket(ulong client_ticket)
    {
        if (client_ticket == 0)
        {
            LOGE("client_ticket = 0");
            return 0;
        }
        ulong res = 0;
        int size = ArraySize(mTradingMap);
        for (int i = 0; i < size; i += 2)
        {
            if (mTradingMap[i + 1] == client_ticket)
            {
                res = mTradingMap[i];
                break;
            }
        }
        return res;
    }

    /**********************************************************************************
    *
    *  load backup data
    *
    ***********************************************************************************/
    void LoadPreviousSession()
    {
        string filePath = GetFilePath();

        // make sure the folder is existed
        CreateDataFolder();

        // đọc file
        int handle = FileOpen(filePath, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
        if(handle != INVALID_HANDLE)
        {
            string jsonStr = "";
            while(!FileIsEnding(handle))
            {
                jsonStr += FileReadString(handle);
            }
            mCptMode = (EnumCopyTradeMode)ParseIntValue(jsonStr, "cpt_mode");
            mSessionId = ParseIntValue(jsonStr, "session_id");
            mWeight = ParseDoubleValue(jsonStr, "weight");
            string arrStr = ParseJsonValue(jsonStr, "trade_data");

            // remove brackets
            StringReplace(arrStr, "[", "");
            StringReplace(arrStr, "]", "");
            // split
            string parts[];
            int count = StringSplit(arrStr, ',', parts);
            ArrayResize(mTradingMap, count);
            for(int i = 0; i < count; i++)
            {
                // trim spaces
                StringTrimLeft(parts[i]);
                StringTrimRight(parts[i]);
                // string -> ulong
                mTradingMap[i] = (ulong)StringToInteger(parts[i]);
            }
            LOGD("load trading data from [" + filePath + "], session=" + (string)mSessionId + " arr=" + arrStr);
        }
        else
        {
            LOGE("Failed to open file: " + filePath);
        }
    }

    /**********************************************************************************
    *
    *  save backup data before terminate
    *
    ***********************************************************************************/
    void SaveSession()
    {
        int size = ArraySize(mTradingMap);
        if (size <= 0)
        {
            LOGD("ignore save session because of no position");
            return;
        }
        JsonBuilder builder;
        builder.Set("cpt_mode", (string)mCptMode);
        builder.Set("session_id", (string)mSessionId);
        builder.Set("weight", (string)mWeight);

        string textData = "[";
        for (int i = 0; i < size; i += 1)
        {
            textData += (string)mTradingMap[i];
            if (i < size - 1) {
                textData += ",";
            }
        }
        textData += "]";
        builder.Set("trade_data", textData);

        // make sure the folder is existed
        CreateDataFolder();

        // save to file
        string filePath = GetFilePath();
        int handle = FileOpen(filePath, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
        if(handle != INVALID_HANDLE)
        {
            FileWrite(handle, builder.Build());
            FileClose(handle);
            LOGD("save to file: " + filePath);
        }
        else
        {
            LOGE("Failed to open file: " + filePath);
        }
    }

    /**********************************************************************************
    *
    *  add/delete function
    *
    ***********************************************************************************/
    void AddCopyTradPosition(ulong serverPosId, ulong myPosId)
    {
        int size = ArraySize(mTradingMap);
        ArrayResize(mTradingMap, size + 2);
        mTradingMap[size] = serverPosId;
        mTradingMap[size + 1] = myPosId;
    }

    void RemoveCopyTradePosition(ulong myPosId)
    {
        int size = ArraySize(mTradingMap);
        for (int i = 0; i < size; i += 2)
        {
            if (mTradingMap[i+1] == myPosId)
            {
                for (int j = i; j < size - 2; j += 2)
                {
                    mTradingMap[j]      = mTradingMap[j + 2];
                    mTradingMap[j + 1]  = mTradingMap[j + 2 + 1];
                }
                ArrayResize(mTradingMap, size - 2);
                break;
            }
        }
    }

    /**********************************************************************************
    *
    *  compare function
    *
    ***********************************************************************************/
    void Compare(iPosition &posArr[], ulong &newPositions[], ulong &closedPositions[])
    {
        int curPosNum = ArraySize(posArr);
        int mapSize = ArraySize(mTradingMap);
        // xác định các position mới
        int i = 0, j = 0, size = 0;
        bool isExisted = false;
        for (i = 0; i < curPosNum; i++)
        {
            isExisted = false;
            for (j = 0; j < mapSize; j += 2)
            {
                if (posArr[i].position_ticket == mTradingMap[j])
                {
                    isExisted = true;
                    break;
                }
            }
            if (isExisted == false)
            {
                size = ArraySize(newPositions);
                ArrayResize(newPositions, size + 1);
                newPositions[size] = posArr[i].position_ticket;
            }
        }

        // xác định các position bị closed:
        for (i = 0; i < mapSize; i += 2)
        {
            isExisted = false;
            for (j = 0; j < curPosNum; j++)
            {
                if (mTradingMap[i] == posArr[j].position_ticket)
                {
                    isExisted = true;
                    break;
                }
            }
            if (isExisted == false)
            {
                size = ArraySize(closedPositions);
                ArrayResize(closedPositions, size + 1);
                closedPositions[size] = mTradingMap[i];
            }
        }
    }
};