#include "../common/Types.mqh"
#include "../common/JsonBuilder.mqh"
#include "CPT_LocalTerminal.mqh"
#include "CPT_CopyTradeSession.mqh"
#include "CPT_InOutManager.mqh"

class CPT_ServerTerminal : public CPT_LocalTerminal
{
private:
    int mClientList[];
    int mClientNumber;

    int mCopyTradeSessionId;

    /**********************************************************************************
    *
    *  init và terminate
    *
    ***********************************************************************************/
public:
    CPT_ServerTerminal() : CPT_LocalTerminal() 
    {
        mClientNumber = 0;
    }

    /*
    *   init server:
    *   + thực hiện load session info trước đó
    *   + thực hiện kiểm tra:
    *       1, client -> server: thực hiện tạo session mới khi ko có pos nào chạy
    *       2, server -> server: chỉ init khi ko có pos nào đang chạy hoặc các pos đều thuộc session cũ
    *       3, unkown -> server: chỉ init khi ko có pos nào.
    */
    bool Init(CPT_InOutManager* inOutController) override
    {
        CPT_LocalTerminal::Init(inOutController);

        // 1: load previous session và kiểm tra
        CPT_CopyTradeSession previousSession();
        previousSession.LoadPreviousSession();
        
        iPosition posArr[];
        TerminalAPI::DoGetAllPosition(posArr);
        ulong closedPosition[];
        ulong newPosition[];
        previousSession.Compare(posArr, newPosition, closedPosition);
        int currentPosNum = ArraySize(posArr);
        int closedPosNum  = ArraySize(closedPosition);
        int newPosNum     = ArraySize(newPosition);
        LOGD("previous mode=" + ToString(previousSession.GetMode()) + 
                                " currentPosNum=" + (string)currentPosNum + 
                                " closedPosNum=" + (string)closedPosNum + 
                                " newPosNum=" + (string)newPosNum);

        bool res = true;
        // kiểm tra mode: nếu trc đó là client, giờ là server
        if (previousSession.GetMode() == eCPT_MODE_CLIENT)
        {
            // không có position nào đang chạy
            if (currentPosNum ==  0)
            {
                mCopyTradeSessionId = MathRand();
            }
            else //if (ArraySize(posArr) > 0)
            {
                LOGD("switch from CLIENT -> SERVER, but some position is existed, close EA");
                TerminalAPI::DoShowMessagePopup("switch from CLIENT -> SERVER, but some position is existed, \nplease close all position first");
                res = false;
            }
        }
        // 2: nếu trc đó là server, giờ vẫn là server
        else if (previousSession.GetMode() == eCPT_MODE_SERVER)
        {
            // không có position nào đang chạy
            if (currentPosNum == 0)
            {
                mCopyTradeSessionId = MathRand();
            }
            // ko có pos bị closed + ko có pos mới -> vẫn là session cũ đang chạy
            else if (closedPosNum == 0 && newPosNum == 0)
            {
                mCopyTradeSessionId = previousSession.GetSessionId();
            }
            else
            {
                TerminalAPI::DoShowMessagePopup("ERROR in INIT SERVER!!!");
                res = false;
            }
        }
        // ko detect dc mode
        else
        {
            if (currentPosNum > 0)
            {
                TerminalAPI::DoShowMessagePopup("ERROR in INIT SERVER!!!");
                res = false;
            }
            else
            {
                mCopyTradeSessionId = MathRand();
            }
        }
        return res;
    }

    void Terminate() override
    {
        iPosition posArr[];
        TerminalAPI::DoGetAllPosition(posArr);
        int size = ArraySize(posArr);
        // no need save session if the size is 0
        if (size <= 0)
        {
            LOGD("ignore save session because of no position");
            return;
        }
        CPT_CopyTradeSession session(eCPT_MODE_SERVER, mCopyTradeSessionId, 0);
        for(int i = 0; i < size; i++)
        {
            session.AddCopyTradPosition(0, posArr[i].position_ticket);
        }
        session.SaveSession();
    }

    /**********************************************************************************
    *
    *  polling functions
    *
    ***********************************************************************************/
    void DoPoll() override
    {
        // giảm thiểu số lượng check file quá nhiều:
        // 5s mới check một lần.
        static int s_pollCount = 0;
        int i = 0, j = 0;
        bool isExisted = false;
        if (s_pollCount % 5 == 0)
        {
            int currList[];
            int currNumber = m_pInOutManager.GetClientList(currList);
            bool changed = false;

            // check new client then noti update for each
            for (i = 0; i < currNumber; i++)
            {
                isExisted = false;
                for (j = 0; j < mClientNumber; j++)
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
            for (i = 0; i < mClientNumber; i++)
            {
                isExisted = false;
                for (j = 0; j < currNumber; j++)
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

    /**********************************************************************************
    *
    *  bussiness logic functions
    *
    ***********************************************************************************/
private:
    void SendUpdateDataToClient(int client_id)
    {
        iPosition currentPositions[];
        TerminalAPI::DoGetAllPosition(currentPositions);

        JsonBuilder builder;
        builder.Set("cmd", (string)eCMD_CPT_UPDATE);
        builder.Set("to_client", (string)client_id);
        builder.Set("curr_positions", currentPositions);

        m_pInOutManager.SendData(builder.Build());
    }

    void OnPositionAdded(iPosition& newPos)
    {
        JsonBuilder builder;
        builder.Set("cmd", (string)eCMD_CPT_POS_ADDED);
        builder.Set("positon_info", newPos);
        
        m_pInOutManager.SendData(builder.Build());
    }

    void OnPositionClosed(iPosition& closedPos)
    {
        JsonBuilder builder;
        builder.Set("cmd", (string)eCMD_CPT_POS_CLOSED);
        builder.Set("positon_info", closedPos);
        
        m_pInOutManager.SendData(builder.Build());
    }
};