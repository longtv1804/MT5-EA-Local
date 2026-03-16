#include "Types.mqh"
#include "Utils.mqh"
#include <Trade/Trade.mqh>

iPosition DoGetPosition(ulong position_ticket)
{
    iPosition ins;
    ZeroMemory(ins);

    if(PositionSelectByTicket(position_ticket))
    {
        ins.position_ticket = position_ticket;
        ins.symbol          = PositionGetString(POSITION_SYMBOL);
        ins.position_type   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        ins.volume          = PositionGetDouble(POSITION_VOLUME);
        ins.price_open      = PositionGetDouble(POSITION_PRICE_OPEN);
        ins.time_open       = (datetime)PositionGetInteger(POSITION_TIME);
        ins.status          = ePOSITION_STATUS_OPEN;
    }
    else
    {
        ins.status = ePOSITION_STATUS_CLOSED;
    }

    return ins;
}

double GetTotalAliveVolume()
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

void DoGetAllPosition(iPosition &resArr[])
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
            resArr[i].position_type   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            resArr[i].status          = ePOSITION_STATUS_OPEN;
            resArr[i].volume          = PositionGetDouble(POSITION_VOLUME);

            resArr[i].price_open      = PositionGetDouble(POSITION_PRICE_OPEN);
            resArr[i].time_open       = (datetime)PositionGetInteger(POSITION_TIME);
            resArr[i].open_reason     = (ENUM_POSITION_REASON)PositionGetInteger(POSITION_REASON);

            resArr[i].price_close     = 0.0;
            resArr[i].time_close      = 0;
            resArr[i].close_reason    = 0;
        }
        else
        {
            LOGE("Failed to select position by ticket: " + IntegerToString(ticket) + " | Error: " + IntegerToString(GetLastError()));
            resArr[i].status = ePOSITION_STATUS_UNKNOWN;
        }
    }     
}

bool DoClosePosition(ulong position_ticket)
{
    if(PositionSelectByTicket(position_ticket))
    {
        CTrade trade;
        return trade.PositionClose(position_ticket);
    }
    return false;
}

bool DoClosePartialPosition(ulong position_ticket, double volume)
{
    if(PositionSelectByTicket(position_ticket))
    {
        CTrade trade;
        return trade.PositionClosePartial(position_ticket, volume);
    }
    return false;
}

void DoEndAllPositions()
{
    CTrade trade;
    int total = PositionsTotal();
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        trade.PositionClose(ticket);
    }
}
