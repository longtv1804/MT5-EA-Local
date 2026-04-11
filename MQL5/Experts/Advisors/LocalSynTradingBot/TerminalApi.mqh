#include "Types.mqh"
#include "Utils.mqh"
class TerminalAPI
{
public:
    static void DoCloseEA ()
    {
        LOGD("@@@ Force to Close EA... @@@");
        ExpertRemove();
    }

    static void DoShowMessagePopup(string message)
    {
        MessageBox(message, "Message from Remote Terminal", MB_OK | MB_ICONINFORMATION);
    }

    static int DoGetPositionCount()
    {
        return OrdersTotal();
    }
    
    static iPosition DoGetPosition(int ticket)
    {
        iPosition ins;
        ZeroMemory(ins);
        if(OrderSelect(ticket, SELECT_BY_TICKET))
        {
            ins.position_ticket = ticket;
            ins.symbol          = OrderSymbol();
            ins.position_type   = OrderType();
            ins.volume          = OrderLots();
            ins.price_open      = OrderOpenPrice();
            ins.status          = ePOSITION_STATUS_OPEN;
        }
        else
        {
            ins.status = ePOSITION_STATUS_CLOSED;
        }
        return ins;
    }

    static double GetTotalAliveVolume()
    {
        double total_volume = 0.0;
        int total = OrdersTotal();
        for(int i = 0; i < total; i++)
        {
            if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
                if(OrderType() == OP_SELL || OrderType() == OP_BUY)
                {
                    total_volume += OrderLots();
                }
            }
        }
        return total_volume;
    }

    static void DoGetAllPosition(iPosition &resArr[])
    {
        int total = OrdersTotal();
        ArrayResize(resArr, total);
        int idx = 0;
        for(int i = 0; i < total; i++)
        {
            if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
                if(OrderType() == OP_SELL || OrderType() == OP_BUY)
                {
                    resArr[idx].position_ticket = OrderTicket();
                    resArr[idx].symbol          = OrderSymbol();
                    resArr[idx].position_type   = OrderType();
                    resArr[idx].status          = ePOSITION_STATUS_OPEN;
                    resArr[idx].volume          = OrderLots();
                    resArr[idx].price_open      = OrderOpenPrice();
                    idx++;
                }
            }
        }
    }

    static bool DoClosePosition(int position_ticket)
    {
        bool res = false;
        if(OrderSelect(position_ticket, SELECT_BY_TICKET))
        {
            if(OrderType() == OP_BUY || OrderType() == OP_SELL)
            {
                double lots = OrderLots();
                double price = (OrderType() == OP_BUY) ? Bid : Ask;
                int slippage = 3;
                res = OrderClose(position_ticket, lots, price, slippage, clrRed);
                if(res)
                    LOGD("Closed position [ " + IntegerToString(position_ticket) + " ]");
                else
                    LOGE("Failed to close [" + IntegerToString(position_ticket) + "] | Error: " + IntegerToString(GetLastError()));
            }
        }
        return res;
    }

    static bool DoClosePartialPosition(int position_ticket, double volume)
    {
        bool res = false;
        if(OrderSelect(position_ticket, SELECT_BY_TICKET))
        {
            if(OrderType() == OP_BUY || OrderType() == OP_SELL)
            {
                double price = (OrderType() == OP_BUY) ? Bid : Ask;
                int slippage = 3;
                res = OrderClose(position_ticket, volume, price, slippage, clrRed);
                if(res)
                    LOGD("Closed partial position [ " + IntegerToString(position_ticket) + " ]");
                else
                    LOGE("Failed to close partial [" + IntegerToString(position_ticket) + "] | Error: " + IntegerToString(GetLastError()));
            }
        }
        return res;
    }

    static void DoEndAllPositions()
    {
        int total = OrdersTotal();
        for(int i = total - 1; i >= 0; i--)
        {
            if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
                if(OrderType() <= OP_SELL && OrderSymbol() == Symbol())
                {
                    int ticket = OrderTicket();
                    double lots = OrderLots();
                    double price = (OrderType() == OP_BUY) ? Bid : Ask;
                    int slippage = 3;
                    bool res = OrderClose(ticket, lots, price, slippage, clrRed);
                    if(res)
                        LOGD("Closed position [ " + IntegerToString(ticket) + " ]");
                    else
                    {
                        LOGE("Failed to close [" + IntegerToString(ticket) + "] | Error: " + IntegerToString(GetLastError()));
                        break;
                    }
                }
            }
        }
    }
};
