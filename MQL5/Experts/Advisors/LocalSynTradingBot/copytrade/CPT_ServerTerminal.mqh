#include "../common/Types.mqh"
#include "CPT_LocalTerminal.mqh"

class CPT_ServerTerminal : public CPT_LocalTerminal
{
private:
    int mClientList[];
    int mClientNumber;

    void SendUpdateDataToClient(int client_id)
    {

    }

public:
    CPT_ServerTerminal() : CPT_LocalTerminal() 
    {
        mClientNumber = 0;
    }

    void OnPositionAdded(iPosition& newPos)
    {
        
    }
    void OnPositionClosed(iPosition& newPos) {}

    void Terminate() override
    {
        
    }

    void DoPoll() override
    {
        // giảm thiểu số lượng check file quá nhiều:
        // 5s mới check một lần.
        static int s_pollCount = 0;
        if (s_pollCount % 5 == 0)
        {
            int currList[];
            int currNumber = m_pInOutManager.GetClientList(currList);
            bool changed = false;

            // check new client then noti update for each
            for (int i = 0; i < currNumber; i++)
            {
                bool isExisted = false;
                for (int j = 0; j < mClientNumber; j++)
                {
                    if (currList[i] == mClientList[j])
                    {
                        isExisted = true;
                    }
                }
                if (isExisted == false)
                {
                    changed = true;
                    LOGD("New Client[" + (string)currList[i] + "]");
                    SendUpdateDataToClient(currList[i]);
                }
            }

            // check missing client and log out
            for (int i = 0; i < mClientNumber; i++)
            {
                bool isExisted = false;
                for (int j = 0; j < currNumber; j++)
                {
                    if (mClientList[i] == currList[j])
                    {
                        isExisted = true;
                    }
                }
                if (isExisted == false)
                {
                    changed = true;
                    LOGD("missing Client[" + (string)currList[i] + "]");
                }
            }

            // clear old data and set latest
            if (changed)
            {
                ArrayCopy(mClientList, currList);
                mClientNumber = currNumber;
            }
        }
        else
        {
            s_pollCount += 1;
        }
    }
};