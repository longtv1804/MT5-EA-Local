#include "../common/Logging.mqh"
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
        mCopyTradeSessionId = 0;
    }

    /*
    *   init server:
    *   + thực hiện load session info trước đó
    *   + thực hiện kiểm tra:
    *       1, client -> server: thực hiện tạo session mới khi ko có pos nào chạy
    *       2, server -> server: chỉ init khi ko có pos nào đang chạy hoặc các pos đều thuộc session cũ
    *       3, unkown -> server: chỉ init khi ko có pos nào.
    */
    bool Init(CPT_SocketChannel* inOutController) override
    {
        CPT_LocalTerminal::Init(inOutController);

        // 1: load previous session và kiểm tra
        CPT_CopyTradeSession previousSession(eCPT_MODE_CLIENT, eSPT_BUY_SELL, 0);
        previousSession.LoadPreviousSession();
        
        iPosition posArr[];
        TerminalAPI::DoGetAllPosition(posArr);
        ulong closedPosition[];
        ulong newPosition[];
        previousSession.Compare(posArr, newPosition, closedPosition);
        int currentPosNum = ArraySize(posArr);
        int closedPosNum  = ArraySize(closedPosition);
        int newPosNum     = ArraySize(newPosition);
        LOGD("previous mode=" + ToString(previousSession.GetMode()));
        LOGD("currentPosNum=" + (string)currentPosNum +" closedPosNum=" + (string)closedPosNum + " newPosNum=" + (string)newPosNum);

        bool res = true;
        // unknown -> server:
        // client  -> server:
        if (previousSession.GetMode() == eCPT_MODE_UNKNOWN
            || previousSession.GetMode() == eCPT_MODE_CLIENT)
        {
            // còn position đang chạy, cần cảnh báo user
            if (currentPosNum >  0)
            {
                TerminalAPI::DoShowMessagePopup("WARNING: -> SERVER: some positions are still existed, please take care of them!!!");
            }
            mCopyTradeSessionId = MathRand();
        }
        // server  -> server:
        else if (previousSession.GetMode() == eCPT_MODE_SERVER)
        {
            // ko có position nào tồn tại
            if (currentPosNum == 0)
            {
                mCopyTradeSessionId = MathRand();
            }
            else
            {
                // nếu dữ liệu trading cũ còn position đang tồn tại
                if (closedPosNum < previousSession.GetClientPositionNumer())
                {
                    mCopyTradeSessionId = MathRand();
                }
                // ko còn 
                else
                {
                    mCopyTradeSessionId = MathRand();
                }
            }
        }
        else
        {
            TerminalAPI::DoShowMessagePopup("ERROR in INIT SERVER: ko xac dinh previous MODE !!!");
            res = false;
        }

        LOGD("SERVER: session=(" + (string)mCopyTradeSessionId + ")");

        if (res)
        {
            LOGD("Init CPT_SocketChannel (SERVER)...");
            res = inOutController.Open();
        }
        return res;
    }

    void Terminate() override
    {
        LOGD("terminate ServerTerminal...");
        iPosition posArr[];
        TerminalAPI::DoGetAllPosition(posArr);
        int size = ArraySize(posArr);

        CPT_CopyTradeSession session(eCPT_MODE_SERVER, mCopyTradeSessionId, 0);
        for(int i = 0; i < size; i++)
        {
            session.AddCopyTradePosition(0, posArr[i].position_ticket);
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
        // accept kết nối mới / đọc dữ liệu / dọn client mất kết nối
        m_pChannel.Pump();

        // quét danh sách client MỖI lần poll:
        //   bản file phải quét thư mục mỗi 5 giây (file I/O đắt) nên mới
        //   có bộ đếm s_pollCount; nay chỉ là đọc mảng trong bộ nhớ -> chạy
        //   luôn, nhờ vậy client mới nhận được UPDATE ngay sau khi kết nối.
        int i = 0, j = 0;
        bool isExisted = false;
        {
            int currList[];
            int currNumber = m_pChannel.GetClientList(currList);
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
                    LOGD("missing Client[" + (string)mClientList[i] + "]");
                }
            }

            // clear old data and set latest
            if (changed)
            {
                ArrayCopy(mClientList, currList);
                mClientNumber = currNumber;
            }
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
        builder.Set("session_id", (string)mCopyTradeSessionId);
        builder.Set("trade_symbol", _Symbol);
        builder.Set("to_client", (string)client_id);
        builder.Set("curr_positions", currentPositions);

        m_pChannel.SendData(builder.Build());
    }

    void OnPositionAdded(const iPosition& newPos) override
    {
        JsonBuilder builder;
        builder.Set("cmd", (string)eCMD_CPT_POS_ADDED);
        builder.Set("session_id", (string)mCopyTradeSessionId);
        builder.Set("position_info", newPos);
        
        m_pChannel.SendData(builder.Build());
    }

    void OnPositionClosed(const iPosition& closedPos) override
    {
        JsonBuilder builder;
        builder.Set("cmd", (string)eCMD_CPT_POS_CLOSED);
        builder.Set("session_id", (string)mCopyTradeSessionId);
        builder.Set("position_info", closedPos);
        
        m_pChannel.SendData(builder.Build());
    }
};