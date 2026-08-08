#include "Types.mqh"
#include "Utils.mqh"
#include "Logging.mqh"
#include "Constants.mqh"
#include "CommonDataCenter.mqh"
#ifdef __MQL5__
#include <Trade/Trade.mqh>
#endif

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
        string server_name = "";
        string broker_name = "";
        string accountName = "";

    #ifdef __MQL5__
        server_name = AccountInfoString(ACCOUNT_SERVER);
        broker_name = AccountInfoString(ACCOUNT_COMPANY);
        accountName = AccountInfoString(ACCOUNT_NAME);
    #else
        server_name = AccountServer();
        broker_name = AccountCompany();
        accountName = AccountName();
    #endif
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
    #ifdef __MQL5__
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
            ins.magic_number    = PositionGetInteger(POSITION_MAGIC);
            ins.status          = ePOSITION_STATUS_OPEN;
        }
        else
        {
            ins.status = ePOSITION_STATUS_UNKNOWN;
        }
    #else // MQL4
        if(OrderSelect((int)position_ticket, SELECT_BY_TICKET))
        {
            int type = OrderType();
            if(type == OP_BUY || type == OP_SELL)
            {
                ins.position_ticket = (ulong)OrderTicket();
                ins.symbol = OrderSymbol();

                if(type == OP_BUY)
                {
                    ins.position_type = ePOSITION_TYPE_BUY;
                }
                else if(type == OP_SELL)
                {
                    ins.position_type = ePOSITION_TYPE_SELL;
                }
                else
                {
                    ins.position_type = ePOSITION_TYPE_UNKNOWN;
                }
                ins.volume = OrderLots();
                ins.price_open = OrderOpenPrice();
                ins.magic_number = OrderMagicNumber();
                ins.status = ePOSITION_STATUS_OPEN;
            }
            else
            {
                ins.status = ePOSITION_STATUS_UNKNOWN;
            }
        }
        else
        {
            LOGE("Failed OrderSelect ticket [" + IntegerToString((int)position_ticket) + "] Error=" + IntegerToString(GetLastError()));
            ins.status = ePOSITION_STATUS_UNKNOWN;
        }
    #endif
        return ins;
    }

    static double GetTotalAliveVolume()
    {
        double total_volume = 0.0;
    #ifdef __MQL5__
        int total = PositionsTotal();
        for(int i = 0; i < total; i++)
        {
            if(PositionSelectByTicket(PositionGetTicket(i)))
            {
                double vol = PositionGetDouble(POSITION_VOLUME);
                total_volume += vol;
            }
        }
    #else // MQL4
        int total = OrdersTotal();
        for(int i = 0; i < total; i++)
        {
            if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
                // chỉ tính market orders đang sống
                int type = OrderType();

                if(type == OP_BUY || type == OP_SELL)
                {
                    total_volume += OrderLots();
                }
            }
        }
    #endif
        return total_volume;
    }

    static bool DoGetAllPosition(iPosition &resArr[])
    {
        ArrayResize(resArr, 0);
    #ifdef __MQL5__
        int i = 0;
        while(true)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket != 0)
            {
                if (PositionSelectByTicket(ticket))
                {
                    ArrayResize(resArr, i + 1);
                    resArr[i] = iPosition();
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
                    resArr[i].magic_number    = PositionGetInteger(POSITION_MAGIC);
                    resArr[i].price_open      = PositionGetDouble(POSITION_PRICE_OPEN);
                }
                else
                {
                    LOGE("Failed to select position by ticket: " + IntegerToString(ticket) + " | Error: " + IntegerToString(GetLastError()));
                    return false;
                }
            }
            else
            {
                int total = PositionsTotal();
                if (total != i)
                {
                    LOGE("Potential BUG in get positions:i=" + (string)i + " toal=" + (string)total);
                }
                break;
            }
            i++;
        }
    #else // MQL4
        int total = OrdersTotal();
        ArrayResize(resArr, total);
        int idx = 0;
        for(int i = 0; i < total; i++)
        {
            if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
                int type = OrderType();
                // chỉ lấy market order
                if(type != OP_BUY && type != OP_SELL)
                    continue;

                resArr[idx] = iPosition();
                resArr[idx].position_ticket = (ulong)OrderTicket();
                resArr[idx].symbol = OrderSymbol();

                if(type == OP_BUY)
                {
                    resArr[idx].position_type = ePOSITION_TYPE_BUY;
                }
                else if(type == OP_SELL)
                {
                    resArr[idx].position_type = ePOSITION_TYPE_SELL;
                }
                else
                {
                    resArr[idx].position_type = ePOSITION_TYPE_UNKNOWN;
                }
                resArr[idx].status = ePOSITION_STATUS_OPEN;
                resArr[idx].volume = OrderLots();
                resArr[idx].price_open = OrderOpenPrice();
                resArr[idx].magic_number = OrderMagicNumber();
                idx++;
            }
            else
            {
                LOGE("Failed OrderSelect index=" + IntegerToString(i) + " Error=" + IntegerToString(GetLastError()));
                return false;
            }
        }
        // resize đúng số lượng market orders
        ArrayResize(resArr, idx);
    #endif
        return true;
    }

    static bool DoClosePosition(ulong position_ticket)
    {
        bool res = false;
    #ifdef __MQL5__
        if(PositionSelectByTicket(position_ticket))
        {
            CTrade trade;
            trade.SetAsyncMode(true);
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
    #else // MQL4
        if(OrderSelect((int)position_ticket, SELECT_BY_TICKET))
        {
            int type = OrderType();
            if(type == OP_BUY || type == OP_SELL)
            {
                double lots  = OrderLots();
                double price = 0;
                if(type == OP_BUY)
                    price = Bid;
                else
                    price = Ask;

                RefreshRates();
                res = OrderClose(OrderTicket(), lots, price, 5/*slippage*/, clrNONE);
                if(res)
                {
                    LOGD("Closed position [" + IntegerToString((int)position_ticket) + "]");
                }
                else
                {
                    LOGE("Failed to close [" + IntegerToString((int)position_ticket) + "] | Error: " + IntegerToString(GetLastError()));
                }
            }
        }
    #endif
        return res;
    }
    
    static bool DoClosePartialPosition(ulong position_ticket, double volume)
    {
        bool res = false;

    #ifdef __MQL5__
        if(PositionSelectByTicket(position_ticket))
        {
            CTrade trade;
            res = trade.PositionClosePartial(position_ticket, volume);
            if(res)
            {
                LOGD("Partial closed position [" + IntegerToString((long)position_ticket) + "] volume=" + DoubleToString(volume, 2));
            }
            else
            {
                LOGE("Failed partial close [" + IntegerToString((long)position_ticket) + "] | Error: " + IntegerToString(GetLastError()));
            }
        }
    #else // MQL4
        if(OrderSelect((int)position_ticket, SELECT_BY_TICKET))
        {
            int type = OrderType();
            if(type == OP_BUY || type == OP_SELL)
            {
                RefreshRates();
                double price = (type == OP_BUY) ? Bid : Ask;
                double lots = OrderLots();
                // không cho close quá volume hiện tại
                if(volume > lots) volume = lots;

                // normalize theo lot step
                double lotstep = MarketInfo(Symbol(), MODE_LOTSTEP);
                volume = NormalizeDouble( MathFloor(volume / lotstep) * lotstep, 2);

                res = OrderClose(OrderTicket(), volume, price, 5, clrNONE);

                if(res)
                {
                    LOGD("Partial closed position [" + IntegerToString((int)position_ticket) + "] volume=" + DoubleToString(volume, 2));
                }
                else
                {
                    LOGE("Failed partial close [" + IntegerToString((int)position_ticket) + "] | Error: " + IntegerToString(GetLastError()));
                }
            }
        }
    #endif
        return res;
    }

    static void DoEndAllPositions()
    {
    #ifdef __MQL5__
        CTrade trade;
        trade.SetAsyncMode(true);
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
    #else // MQL4
        while(OrdersTotal() > 0)
        {
            bool found = false;
            for(int i = OrdersTotal() - 1; i >= 0; i--)
            {
                if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                {
                    int type = OrderType();
                    if(type == OP_BUY || type == OP_SELL)
                    {
                        found = true;
                        RefreshRates();
                        double price = (type == OP_BUY) ? Bid : Ask;

                        bool res = OrderClose( OrderTicket(), OrderLots(), price, 5, clrNONE);

                        if(res) {
                            LOGD("Closed position [" + IntegerToString(OrderTicket()) + "]");
                        }
                        else
                        {
                            LOGE("Failed to close [" + IntegerToString(OrderTicket()) + "] | Error: " + IntegerToString(GetLastError()));
                            return;
                        }
                    }
                }
            }
            // tránh infinite loop
            if(!found) break;
        }
    #endif
    }

    static bool Do_OpendPosition(const CopyTradeReqData &reqInfo)
    {
        bool res = false;
    #ifdef __MQL5__
        CTrade trade;
        trade.SetExpertMagicNumber(reqInfo.tracking_number);
        trade.SetAsyncMode(true);
        if (reqInfo.position_type == ePOSITION_TYPE_BUY)
        {
            res = trade.Buy(reqInfo.volume);
        }
        else if (reqInfo.position_type == ePOSITION_TYPE_SELL)
        {
            res = trade.Sell(reqInfo.volume);
        }
        else
        {
            LOGE("ERROR: wrong position_type.");
        }

        if(res)
        {
            LOGD("place buy order ok");
        }
        else
        {
            LOGD("Error in place buy order: " + (string)GetLastError());
        }
    #else // MQL4
        RefreshRates();
        int ticket = 0;
        if (reqInfo.position_type == ePOSITION_TYPE_BUY)
        {
            ticket = OrderSend(Symbol(), OP_BUY, reqInfo.volume, Ask, 5/*slippage*/, 0/*stoploss*/, 0/*takeprofit*/,
                        "CopyTrade", (int)reqInfo.tracking_number, 0, clrBlue);
        }
        else if (reqInfo.position_type == ePOSITION_TYPE_SELL)
        {
            ticket = OrderSend(Symbol(), OP_SELL, reqInfo.volume, Ask, 5/*slippage*/, 0/*stoploss*/, 0/*takeprofit*/,
                        "CopyTrade", (int)reqInfo.tracking_number, 0, clrBlue);
        }
        else
        {
            LOGE("ERROR: wrong position_type.");
        }

        res = (ticket > 0);
        if(res)
        {
            LOGD("Place BUY order OK, ticket=" + IntegerToString(ticket));
        }
        else
        {
            LOGE("Error place BUY order: " +  IntegerToString(GetLastError()));
        }
    #endif
        return res;
    }

    static bool Do_ClosePosition(const CopyTradeReqData &reqInfo)
    {
        ulong ticket = reqInfo.target_ticket;
        if (ticket == 0)
        {
            LOGD("ticket is 0");
            return false;
        }

    #ifdef __MQL5__
        if(!PositionSelectByTicket(ticket))
        {
            LOGD("PositionSelectByTicket failed " + (string)ticket);
            return false;
        }

        string symbol = PositionGetString(POSITION_SYMBOL);
        
        CTrade trade;
        trade.SetAsyncMode(true);
        bool ok = trade.PositionClose(ticket);
        if(!ok)
        {
            LOGD(StringFormat("PositionClose ticket:" + (string)ticket + "  failed retcode=%d desc=%s", 
                                trade.ResultRetcode(), trade.ResultRetcodeDescription()));
            return false;
        }
    #else // MQL4
        if(!OrderSelect((int)ticket, SELECT_BY_TICKET))
        {
            LOGD("OrderSelect failed" + (string)ticket);
            return false;
        }

        int type = OrderType();
        if(type != OP_BUY && type != OP_SELL)
        {
            LOGD("Not market order " + (string)ticket);
            return false;
        }

        string symbol = OrderSymbol();
        double lots = OrderLots();
        RefreshRates();

        double price = (type == OP_BUY) ? MarketInfo(symbol, MODE_BID) : MarketInfo(symbol, MODE_ASK);
        LOGD(StringFormat("Closing order ticket=%I64u symbol=%s volume=%f", ticket, symbol, lots));
        bool ok = OrderClose((int)ticket, lots, price, 10, clrNONE);
        if(!ok)
        {
            LOGD("OrderClose failed ticket:" + (string)ticket + " err=" + (string)GetLastError());
            return false;
        }
    #endif
        LOGD(StringFormat("Close success ticket=%I64u", ticket));
        return true;
    }

    static void SendEmail(string title, string content)
    {
        string server_name = AccountInfoString(ACCOUNT_SERVER);
        #ifdef __MQL5__
        long acc_id = AccountInfoInteger(ACCOUNT_LOGIN);
        #else
        long acc_id = AccountNumber();
        #endif

        bool result = SendMail(
            "[" + server_name + " - " + (string)acc_id + "]" + title,
            "server:" + server_name + "\n" +
            "acc:" + (string)acc_id + "\n\n" +
            content
        );

        if(result) {
            LOGD("notificaition sent");
        }
        else {
            LOGE("SendMail failed. Error=" + (string)GetLastError());
        }
    }

    static int GetPositionCount()
    {
        #ifdef __MQL5__
        int total = PositionsTotal();
        #else
        int total = OrdersTotal();
        #endif
        return total;
    }

    static double GetFloatingPNL()
    {
        double floatingPnl = 0;
        #ifdef __MQL5__
        floatingPnl = AccountInfoDouble(ACCOUNT_EQUITY) - AccountInfoDouble(ACCOUNT_BALANCE);
        #else
        floatingPnl = AccountEquity() - AccountBalance();
        #endif
        return floatingPnl;
    }

    static double GetCurrentPrice(string symbol, bool isBuy)
    {
    #ifdef __MQL5__
        return SymbolInfoDouble(symbol, isBuy ? SYMBOL_ASK : SYMBOL_BID);
    #else
        RefreshRates();
        return isBuy ? Ask : Bid;
    #endif
    }
};