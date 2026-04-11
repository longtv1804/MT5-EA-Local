#include "Types.mqh"
#include "Utils.mqh"
#include <Trade/Trade.mqh>

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
        MessageBox(message, "EA Message", MB_OK | MB_ICONINFORMATION);
    }

    static iPosition DoGetPosition(ulong position_ticket)
    {
        iPosition ins;
        ZeroMemory(ins);

        if(PositionSelectByTicket(position_ticket))
        {
            ins.position_ticket = position_ticket;
            ins.symbol          = PositionGetString(POSITION_SYMBOL);
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if (pos_type == POSITION_TYPE_BUY)
            {
                ins.position_type = ePOSITION_TYPE_BUY;
            }
            else if (pos_type == POSITION_TYPE_SELL)
            {
                ins.position_type = ePOSITION_TYPE_SELL;
            }
            else
            {
                ins.position_type = ePOSITION_TYPE_UNKNOWN;
            }
            ins.volume          = PositionGetDouble(POSITION_VOLUME);
            ins.price_open      = PositionGetDouble(POSITION_PRICE_OPEN);
            ins.status          = ePOSITION_STATUS_OPEN;
        }
        else
        {
            ins.status = ePOSITION_STATUS_UNKNOWN;
        }

        return ins;
    }

    static double GetTotalAliveVolume()
    {
        double total_volume = 0.0;
        int total = PositionsTotal();

        for(int i = 0; i < total; i++)
        {
            if(PositionSelectByTicket(PositionGetTicket(i)))
            {
                double vol = PositionGetDouble(POSITION_VOLUME);
                total_volume += vol;
            }
        }
        return total_volume;
    }

    static void DoGetAllPosition(iPosition &resArr[])
    {
        int total = PositionsTotal();
        ArrayResize(resArr, total);

        for(int i = 0; i < total; i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
                resArr[i].position_ticket = ticket;
                resArr[i].symbol          = PositionGetString(POSITION_SYMBOL);
                ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                if (pos_type == POSITION_TYPE_BUY)
                {
                    resArr[i].position_type = ePOSITION_TYPE_BUY;
                }
                else if (pos_type == POSITION_TYPE_SELL)
                {
                    resArr[i].position_type = ePOSITION_TYPE_SELL;
                }
                else
                {
                    resArr[i].position_type = ePOSITION_TYPE_UNKNOWN;
                }
                resArr[i].status          = ePOSITION_STATUS_OPEN;
                resArr[i].volume          = PositionGetDouble(POSITION_VOLUME);

                resArr[i].price_open      = PositionGetDouble(POSITION_PRICE_OPEN);
            }
            else
            {
                LOGE("Failed to select position by ticket: " + IntegerToString(ticket) + " | Error: " + IntegerToString(GetLastError()));
                resArr[i].status = ePOSITION_STATUS_UNKNOWN;
            }
        }     
    }

    static bool DoClosePosition(ulong position_ticket)
    {
        bool res = false;
        if(PositionSelectByTicket(position_ticket))
        {
            CTrade trade;
            res = trade.PositionClose(position_ticket);
            if (res == true)
            {
                LOGD("Closed position [ " + IntegerToString(position_ticket) + " ]");
            }
            else
            {
                LOGE("Failed to close [" + IntegerToString(position_ticket) + "] | Error: " + IntegerToString(GetLastError()));
            }
        }
        return res;
    }

    static bool DoClosePartialPosition(ulong position_ticket, double volume)
    {
        bool res = false;
        if(PositionSelectByTicket(position_ticket))
        {
            CTrade trade;
            res = trade.PositionClosePartial(position_ticket, volume);
            if (res == true)
            {
                LOGD("Closed position [ " + IntegerToString(position_ticket) + " ]");
            }
            else
            {
                LOGE("Failed to close [" + IntegerToString(position_ticket) + "] | Error: " + IntegerToString(GetLastError()));
            }

        }
        return res;
    }

    static void DoEndAllPositions()
    {
        CTrade trade;
        int total = PositionsTotal();
        while (total > 0)
        {
            ulong ticket = PositionGetTicket(0);
            bool res = trade.PositionClose(ticket);
            if (res == true)
            {
                LOGD("Closed position [ " + IntegerToString(ticket) + " ]");
            }
            else
            {
                LOGE("Failed to close [" + IntegerToString(ticket) + "] | Error: " + IntegerToString(GetLastError()));
                break;
            }
            total -= 1;
        }
    }

};