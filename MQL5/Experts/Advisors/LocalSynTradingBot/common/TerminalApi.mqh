#include "Types.mqh"
#include "Utils.mqh"
#include "Constants.mqh"
#include "CommonDataCenter.mqh"
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

    static void DetectBroker()
    {
        string server_name = AccountInfoString(ACCOUNT_SERVER);
        string broker_name = AccountInfoString(ACCOUNT_COMPANY);
        string accountName = AccountInfoString(ACCOUNT_NAME);
        StringToLower(server_name);
        LOGD("server_name=[" + server_name + "], broker_name=[" + broker_name + "], accountName=[" + accountName + "]");
        if (broker_name == BROKER_NAME_FPG)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_FPG;
        }
        else if (broker_name == BROKER_NAME_ULTIMA)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_ULTIMA;
        }
        else if (broker_name == BROKER_NAME_PEPRE)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_PEPRE;
        }
        else if (broker_name == BROKER_NAME_VANTAGE)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_VANTAGE;
        }
        else if(StringFind(server_name, "exness") >= 0)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_EXNESS;
        }
        else if(StringFind(server_name, "xmglobal") >= 0)
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_XM;
        }
        else
        {
            CommonDatacenter::sLOCAL_TERMINAL_TYPE  = eTERMINAL_TYPE_UNKNOWN;
        }
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

    static bool DoCopyTrade_OpendPosition(CopyTradeEvent &ev)
    {
        CTrade trade;
        MathSrand(GetTickCount());
        ev.tracking_number = ((ulong)MathRand() << 16) | (ulong)MathRand();
        trade.SetExpertMagicNumber(ev.tracking_number);

        bool res = trade.Buy(ev.volume);
        if(res)
        {
            LOGD("place buy order ok");
        }
        else
        {
            LOGD("Error in place buy order: " + (string)GetLastError());
        }
        return res;
    }

    static bool DoCopyTrade_ClosePosition(CopyTradeEvent &ev)
    {
        ulong ticket = ev.target_ticket;
        if (ticket == 0)
        {
            LOGD("ticket is 0");
            return false;
        }

        if(ev.volume <= 0)
        {
            LOGD("invalid volume");
            return false;
        }

        #ifdef __MQL5__

            // =========================================
            // MQL5
            // =========================================

            if(!PositionSelectByTicket(ticket))
            {
                LOGD("PositionSelectByTicket failed");
                return false;
            }

            string symbol = PositionGetString(POSITION_SYMBOL);
            double pos_volume = PositionGetDouble(POSITION_VOLUME);
            double close_volume = MathMin(ev.volume, pos_volume);

            CTrade trade;
            bool ok = trade.PositionClosePartial(ticket, close_volume);

            if(!ok)
            {
                LOGD(StringFormat("PositionClosePartial failed retcode=%d desc=%s", 
                                    trade.ResultRetcode(), trade.ResultRetcodeDescription()));
                return false;
            }
            LOGD(StringFormat("Close success ticket=%I64u close_volume=%f", ticket, close_volume));
            return true;
        #else

            // =========================================
            // MQL4
            // =========================================

            if(!OrderSelect((int)ticket, SELECT_BY_TICKET))
            {
                LOGD("OrderSelect failed");
                return false;
            }

            int type = OrderType();
            if(type != OP_BUY && type != OP_SELL)
            {
                LOGD("Not market order");
                return false;
            }

            string symbol = OrderSymbol();
            double lots = OrderLots();
            double close_volume = MathMin(ev.volume, lots);

            RefreshRates();
            double price = (type == OP_BUY) ? MarketInfo(symbol, MODE_BID) : MarketInfo(symbol, MODE_ASK);

            LOGD(StringFormat("Closing order ticket=%I64u symbol=%s volume=%f", ticket, symbol, close_volume));

            bool ok = OrderClose((int)ticket, close_volume, price, 10, clrNONE);
            if(!ok)
            {
                LOGD("OrderClose failed err=" + (string)GetLastError());

                return false;
            }
            LOGD("Close success");
            return true;

        #endif
    }
};