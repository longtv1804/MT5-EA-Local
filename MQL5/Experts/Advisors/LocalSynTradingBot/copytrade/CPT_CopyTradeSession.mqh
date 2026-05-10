#include <Generic/HashMap.mqh>
#include <Trade/Trade.mqh>
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

    string GetFilePath()
    {
        string server_name = AccountInfoString(ACCOUNT_SERVER);
        string broker_name = AccountInfoString(ACCOUNT_COMPANY);
        string accountName = AccountInfoString(ACCOUNT_NAME);
        server_name = NormalizeBrokerName(server_name);
        broker_name = NormalizeBrokerName(broker_name);
        accountName = NormalizeBrokerName(accountName);
        return FOLDER_EA_DIR + "\\CPT_DATA\\" + broker_name + "_" + server_name + "_" + accountName + ".dat";
    }

    void CreateDataFolder()
    {
        // tạo thư mục để chắc chắn thư mục tồn tại
        if (!FileIsExist(FOLDER_EA_DIR + "\\CPT_DATA\\", FILE_COMMON))
        {
            FolderCreate(FOLDER_EA_DIR + "\\CPT_DATA\\", FILE_COMMON);
        }
    }

public:
    CPT_CopyTradeSession() {}
    CPT_CopyTradeSession(EnumCopyTradeMode mode, int id, int weight) 
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
    
    void GetMode()
    {
        return mCptMode;
    }

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

    void SaveSession()
    {
        int size = ArraySize(mTradingMap);
        if (size > 0)
        {
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
};