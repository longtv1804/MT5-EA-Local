#include "../queue/Handler.mqh"
#include "../queue/Event.mqh"
#include "../common/Types.mqh"
#include "../common/TerminalApi.mqh"
#include "CPT_CopyTradeSession.mqh"

#define STRATEGY_LOGD(x) LOGD(StringFormat("[%s] %s", (string)mStrategyPositionType, x))
#define STRATEGY_LOGE(x) LOGE(StringFormat("[%s] %s", (string)mStrategyPositionType, x))

class Event;

class CPT_Strategy : public Handler
{
protected:
    enum EnumCopyTradeEvent
    {
        EV_ADD_NEW_POSITION = 1,
        EV_ADD_NEW_POSITION_DONE,
        EV_CLOSED_POSITION,
        EV_CLOSED_POSITION_DONE,
        
        EV_PENDING_CLOSE_NOT_ADDED_POSITION,
        EV_PENDING_WAITING_NEW_POSITION,
        EV_PENDING_WAITING_CLOSE_POSITION,

        EV_STATEGY_UPDATE_PARAMS
    };

    static string EventToString(int evid)
    {
        switch (evid)
        {
            case EV_ADD_NEW_POSITION:       return "EV_ADD_NEW_POSITION";
            case EV_ADD_NEW_POSITION_DONE:  return "EV_ADD_NEW_POSITION_DONE";
            case EV_CLOSED_POSITION:        return "EV_CLOSED_POSITION";
            case EV_CLOSED_POSITION_DONE:   return "EV_CLOSED_POSITION_DONE";
            case EV_PENDING_CLOSE_NOT_ADDED_POSITION:   return "EV_PENDING_CLOSE_NOT_ADDED_POSITION";
            case EV_PENDING_WAITING_NEW_POSITION:       return "EV_PENDING_WAITING_NEW_POSITION";
            case EV_PENDING_WAITING_CLOSE_POSITION:     return "EV_PENDING_WAITING_CLOSE_POSITION";
            case EV_STATEGY_UPDATE_PARAMS:              return "EV_STATEGY_UPDATE_PARAMS";
            default: return (string) evid;
        }
    }

    // EnumStrategyPositionType là thông tin để nhận biết các 
    // position type nào (sell/buy/both) được xử lý và lưu trong mSession
    EnumStrategyPositionType mStrategyPositionType;

    // lưu trữ các ticket-id theo cặp [server][client]
    CPT_CopyTradeSession mSession;

    virtual void Do_OpendPosition(const Event &ev) = 0;
    virtual void Do_ClosePosition(const Event &ev) = 0;

    virtual void On_OpendPositionDone(const Event &ev) = 0;
    virtual void On_ClosePositionDone(const Event &ev) = 0;
    virtual void On_WaitingCloseNotAddedPosDone(const Event &pendingEv) = 0;
    virtual void On_WaitingNewPosDone(const Event &pendingEv) = 0;
    virtual void On_WaitingClosePosDone(const Event &pendingEv) = 0;

public:
    virtual void OnLocal_PositionAdded(const iPosition& newPos) = 0;
    virtual void OnLocal_PositionClosed(const iPosition& closedPos) = 0;
    virtual void OnServer_NewPositionAdded(const iPosition &newPos) = 0;
    virtual void OnServer_PositionClosed(const iPosition &closedPos) = 0;

protected:
    // check xem position có thuộc về Strategy này không
    bool CheckPositionByType(const iPosition& pos)
    {
        if (mStrategyPositionType == eSPT_BUY_SELL || 
            (mStrategyPositionType == eSPT_BUY && pos.position_type == ePOSITION_TYPE_BUY) ||
            (mStrategyPositionType == eSPT_SELL && pos.position_type == ePOSITION_TYPE_SELL))
        {
            return true;
        }
        return false;
    }

    // check xem server-position có thuộc về Strategy này không
    bool CheckServerPositionByType(const iPosition& server_pos)
    {
        if (mStrategyPositionType == eSPT_BUY_SELL || 
            (mStrategyPositionType == eSPT_BUY && server_pos.position_type == ePOSITION_TYPE_BUY) ||
            (mStrategyPositionType == eSPT_SELL && server_pos.position_type == ePOSITION_TYPE_SELL))
        {
            return true;
        }
        return false;
    }

    // check xem server-position có thuộc về Strategy này không.
    // dành cho plan vào lệnh ngược với server
    // server: buy -> client: sell
    // server: sell -> client: buy
    bool RP_CheckServerPositionByType(const iPosition& server_pos)
    {
        if (mStrategyPositionType == eSPT_BUY_SELL || 
            (mStrategyPositionType == eSPT_BUY && server_pos.position_type == ePOSITION_TYPE_SELL) ||
            (mStrategyPositionType == eSPT_SELL && server_pos.position_type == ePOSITION_TYPE_BUY))
        {
            return true;
        }
        return false;
    }

private:
    void GetPositionByType(iPosition& targetArr[])
    {
        iPosition currentPositionsArr[];
        TerminalAPI::DoGetAllPosition(currentPositionsArr);
        int currPosSize = ArraySize(currentPositionsArr);
        int targetSize = 0;
        ArrayResize(targetArr, 0);
        for (int i = 0; i < currPosSize; i++)
        {
            if (CheckPositionByType(currentPositionsArr[i]))
            {
                ArrayResize(targetArr, targetSize + 1);
                targetArr[targetSize] = currentPositionsArr[i];
                targetSize += 1;
            }
        }
    }

public:
    CPT_Strategy(EnumStrategyPositionType type, double weight) 
    : mSession(eCPT_MODE_CLIENT, type, weight), // sử dụng EnumStrategyPositionType làm sessionId
    mStrategyPositionType(type)
    {
    }

    virtual ~CPT_Strategy()
    {
    }

    bool Init()
    {
        // chủ yếu init liên quan tới session:
        // load session cũ
        // sau đó update session cũ theo latest positions đang có

        // 1: load previous session và kiểm tra
        CPT_CopyTradeSession previousSession(eCPT_MODE_CLIENT, mStrategyPositionType, 0);
        previousSession.LoadPreviousSession();

        // 2. lấy thông tin position list hiện tại và lọc theo mStrategyPositionType
        iPosition posArr[];
        GetPositionByType(posArr);

        ulong closedPosition[];
        ulong newPosition[];
        previousSession.Compare(posArr, newPosition, closedPosition);
        int currentPosNum = ArraySize(posArr);
        int closedPosNum  = ArraySize(closedPosition);
        int newPosNum     = ArraySize(newPosition);
        STRATEGY_LOGD("previous mode=" + ToString(previousSession.GetMode()) + " preWeight=" + (string)previousSession.GetWeight() + "nowWeight=" + (string)mSession.GetWeight());
        STRATEGY_LOGD("currentPosNum=" + (string)currentPosNum + " closedPosNum=" + (string)closedPosNum + " newPosNum=" + (string)newPosNum);

        // 3. update mSession với latest position list
        bool res = true;
        int i = 0, j = 0;
        // unknown -> client:
        // client  -> client:
        //          lấy theo trading map cũ rồi update theo trạng thái hiện tại
        if (previousSession.GetMode() == eCPT_MODE_UNKNOWN
            || previousSession.GetMode() == eCPT_MODE_CLIENT)
        {
            previousSession.CopyTradingMap(mSession);
            mSession.UpdateLatestPosition(posArr);
        }
        // server  -> client: 
        //      update session theo trạng thái hiện tại (ko lấy dữ liệu cũ)
        //      nếu còn position đang chạy thì warning cho user
        else if (previousSession.GetMode() == eCPT_MODE_SERVER)
        {
            if (currentPosNum > 0)
            {
                TerminalAPI::DoShowMessagePopup("SERVER -> CLIENT: some Positions are existed!!! be carefull!!!");
            }
            mSession.UpdateLatestPosition(posArr);
        }
        else
        {
            TerminalAPI::DoShowMessagePopup("ERROR init CLIENT: invalid previous Mode");
            res = false;
        }
        return res;
    }

    // hàm này hơi đặc biệt
    // các strategy khác phải ghi đè hàm và lọc lại server_positions và 
    // now_client_positions trước khi gọi hàm này để xử lý
    virtual void OnServerUpdate(const iPosition &server_positions[], const iPosition &now_client_positions[])
    {
        int server_posNum = ArraySize(server_positions);
        int now_client_posNum = ArraySize(now_client_positions);

        int i = 0, j = 0;
        bool isExisted = false;
        //*********************************************************************************
        // update thông tin session theo thực trạng của server
        //      1, server new position: add [ticket, 0]
        //      2, server closed positon: check nếu tồn tại trong sesison
        //              2.1, position chưa close -> thực hiện close position
        //              2.2, position đã close   -> remove khỏi session
        //*********************************************************************************
        // 1, server new position: add [ticket, 0]
        for (i = 0; i < server_posNum; i++)
        {
            if (mSession.HasServerTicket(server_positions[i].position_ticket) == false)
            {
                mSession.AddCopyTradePosition(server_positions[i].position_ticket, 0);
            }
        }
        
        // 2, check server closed positon:
        //      2.1 tìm tất cả các ticket mà đã bị close
        //      2.2 thực hiện close bên client nếu ticket-positon đối ứng vẫn tồn tại
        //          remove trong mSession nếu ticket đối ứng ko tồn tại
        ulong tradingMap[];
        mSession.GetTradingData(tradingMap);
        int tradingMapSize = ArraySize(tradingMap);
        // 2.1
        ulong server_closedTickets[];
        ArrayResize(server_closedTickets, tradingMapSize/2);
        int closedTicketsCount = 0;
        for (i = 0; i < tradingMapSize; i += 2)
        {
            if (tradingMap[i] != 0)
            {
                isExisted = false;
                for (j = 0; j < server_posNum; j++)
                {
                    if (tradingMap[i] == server_positions[j].position_ticket)
                    {
                        isExisted = true; break;
                    }
                }
                if (isExisted == false)
                {
                    server_closedTickets[closedTicketsCount] = tradingMap[i];
                    closedTicketsCount += 1;
                }
            }
        }
        // 2.2
        STRATEGY_LOGD("server has " + (string)closedTicketsCount + " positions closed.");
        for (i = 0; i < closedTicketsCount; i++)
        {
            ulong server_ticket = server_closedTickets[i];
            ulong client_ticket = mSession.GetClientTicket(server_ticket);
            
            isExisted = false;
            for (j = 0; j < now_client_posNum; j++)
            {
                if (client_ticket == now_client_positions[j].position_ticket)
                {
                    isExisted = true; break;
                }
            }
            if (isExisted == true)
            {
                STRATEGY_LOGD("Process closed position [" + (string)server_ticket + ", " + (string)client_ticket + "]");
                Event ev = ObtainEvent(EV_CLOSED_POSITION);
                ev.arg_ulong_1 = server_ticket;
                ev.arg_ulong_2 = client_ticket;
                SendEvent(ev);
            }
            else
            {
                mSession.RemoveCopyTradePosition(server_closedTickets[i], client_ticket);
            }
        }

        //*********************************************************************************
        // C, update state và logging
        //*********************************************************************************
        mSession.Logging();
    }

    void Terminate()
    {
        mSession.SaveSession();
    }
};