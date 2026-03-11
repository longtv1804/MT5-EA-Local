#include <Trade/Trade.mqh>

class TpSLController
{
    datetime last_check;
    CTrade trade;
    double sl_positive;

    double iEquity_Og;
    double iPercent_SetTP;
    double iPercent_ClearTP;
    double iVal_TP;

public:
    TpSLController() : last_check(0), sl_positive(0.0) {}
    ~TpSLController() {}

    //+------------------------------------------------------------------+
    //| Expert initialization                                            |
    //+------------------------------------------------------------------+
    int Init(double Equity_Og, double Percent_SetTP, double Percent_ClearTP, double Val_TP)
    {
        this.iEquity_Og = Equity_Og;
        this.iPercent_SetTP = Percent_SetTP;
        this.iPercent_ClearTP = Percent_ClearTP;
        this.iVal_TP = Val_TP;

        if (iVal_TP <= 0.0)
        {
            MessageBox(
            "Error: TP price is not set correctly!\n"
            "Please enter TP > 0 before running EA.",
            "EquityTP_EA",
            MB_ICONERROR);
            return INIT_FAILED;
        }

        int total_positions = PositionsTotal();
        double highest_open = 0.0;
        for (int i = 0; i < total_positions; i++)
        {
            ulong ticket = PositionGetTicket(i);
            if (!PositionSelectByTicket(ticket))
            continue;

            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            if (open_price > highest_open)
            highest_open = open_price;
        }

        // ✅ ADDED: Normalize SL Positive to symbol digits
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        sl_positive = NormalizeDouble(MathFloor(highest_open), digits);

        Print("=== EA INIT START ===");
        Print("Equity original : ", iEquity_Og);
        Print("Set TP at       : ", iPercent_SetTP, " %");
        Print("Clear TP at     : ", iPercent_ClearTP, " %");
        Print("TP price        : ", iVal_TP);
        Print("SL price        : ", sl_positive);
        Print("=== EA INIT DONE ===");

        return INIT_SUCCEEDED;
    }

    //+------------------------------------------------------------------+
    //| Expert tick function                                             |
    //+------------------------------------------------------------------+
    void OnTick()
    {
        if (TimeCurrent() - last_check < 5)
            return;

        last_check = TimeCurrent();

        double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
        double percent_change = ((equity_now - iEquity_Og) / iEquity_Og) * 100.0;
        int total_positions = PositionsTotal();

        // ================= NO POSITION =================
        if (total_positions == 0)
        {
            MessageBox("Do not exist ticket. Close EA!!!",
            "EA Warning", MB_ICONERROR);
            ExpertRemove();
            return;
        }

        // ================= SET TP + POSITIVE SL =================
        if (percent_change >= iPercent_SetTP)
        {
            for (int i = 0; i < total_positions; i++)
            {
                ulong ticket = PositionGetTicket(i);
                if (!PositionSelectByTicket(ticket))
                    continue;

                double tp_old = PositionGetDouble(POSITION_TP);
                double sl_old = PositionGetDouble(POSITION_SL);

                if (tp_old <= 0 || sl_old <= 0)
                {
                    MqlTradeRequest req;
                    MqlTradeResult res;
                    ZeroMemory(req);
                    ZeroMemory(res);

                    req.action = TRADE_ACTION_SLTP;
                    req.position = ticket;
                    req.symbol = PositionGetString(POSITION_SYMBOL);
                    req.tp = iVal_TP + ((ticket % 2) * 0.02);
                    req.sl = sl_positive;

                    if (!OrderSend(req, res) || res.retcode != TRADE_RETCODE_DONE)
                    {
                        PrintFormat("ERROR: Failed to set TP/SL | ticket=%I64u | retcode=%d | comment=%s",
                        ticket, res.retcode, res.comment);
                        CloseAllPositions();
                        return;
                    }
                    else
                    {
                        PrintFormat("INFO: TP=%.5f | SL=%.5f | ticket=%I64u",
                        req.tp, sl_positive, ticket);
                    }
                }
            }
            return;
        }

        // ==========================================================
        // 2) REMOVE SL IF EQUITY < 150% OF ORIGINAL
        // ==========================================================
        if (percent_change < 50)
        {
            for (int i = 0; i < total_positions; i++)
            {
                ulong ticket = PositionGetTicket(i);
                if (!PositionSelectByTicket(ticket))
                    continue;

                double sl_old = PositionGetDouble(POSITION_SL);
                double tp_old = PositionGetDouble(POSITION_TP);

                if (sl_old <= 0.0)
                    continue;

                MqlTradeRequest req;
                MqlTradeResult res;
                ZeroMemory(req);
                ZeroMemory(res);

                req.action = TRADE_ACTION_SLTP;
                req.position = ticket;
                req.symbol = PositionGetString(POSITION_SYMBOL);
                req.sl = 0.0;
                req.tp = tp_old;

                if (!OrderSend(req, res) || res.retcode != TRADE_RETCODE_DONE)
                {
                    PrintFormat("ERROR: Failed to remove SL | ticket=%I64u | retcode=%d | comment=%s",
                    ticket, res.retcode, res.comment);
                }
                else
                {
                    PrintFormat("INFO: SL removed | ticket=%I64u", ticket);
                }
            }
        }

        // ==========================================================
        // 3) CLEAR TP + SL ON DRAWDOWN
        // ==========================================================
        if (percent_change <= iPercent_ClearTP)
        {
            for (int i = 0; i < total_positions; i++)
            {
                ulong ticket = PositionGetTicket(i);
                if (!PositionSelectByTicket(ticket))
                    continue;

                double tp_old = PositionGetDouble(POSITION_TP);
                if (tp_old <= 0.0)
                continue;

                MqlTradeRequest req;
                MqlTradeResult res;
                ZeroMemory(req);
                ZeroMemory(res);

                req.action = TRADE_ACTION_SLTP;
                req.position = ticket;
                req.symbol = PositionGetString(POSITION_SYMBOL);
                req.tp = 0.0;
                req.sl = 0.0;

                if (!OrderSend(req, res) || res.retcode != TRADE_RETCODE_DONE)
                {
                    PrintFormat("ERROR: Failed to clear TP/SL | ticket=%I64u | retcode=%d | comment=%s",
                    ticket, res.retcode, res.comment);
                }
                else
                {
                    PrintFormat("INFO: TP and SL cleared | ticket=%I64u", ticket);
                }
            }

            return;
        }

        PrintFormat("INFO: Equity=%.2f | Change=%.2f%%",
        equity_now, percent_change);
    }
   //+------------------------------------------------------------------+

    // ================= CLOSE ALL USING CTrade =================
    void CloseAllPositions()
    {
        int total = PositionsTotal();

        for (int i = total - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if (!PositionSelectByTicket(ticket))
                continue;

            bool result = trade.PositionClose(ticket);

            if (!result)
            {
                PrintFormat("ERROR: CTrade failed to close | ticket=%I64u | retcode=%d | description=%s",
                ticket,
                trade.ResultRetcode(),
                trade.ResultRetcodeDescription());
            }
            else
            {
                PrintFormat("INFO: Position closed | ticket=%I64u",
                ticket);
            }
        }

        Print("INFO: ALL POSITIONS CLOSE FINISHED.");
    }
    //+------------------------------------------------------------------+
};