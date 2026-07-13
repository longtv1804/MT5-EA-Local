#include "../common/Types.mqh"
#include "../lib/ByteBuffer.mqh"
#include "Event.mqh"

class EventUtils
{
    static void ToData(Event &evTarget, const iPosition& pos)
    {
        ByteBuffer buffer;
        buffer.WriteULong(pos.position_ticket);
        buffer.WriteString(pos.symbol);
        buffer.WriteInt(pos.position_type);
        buffer.WriteInt(pos.status);
        buffer.WriteDouble(pos.volume);
        buffer.WriteDouble(pos.price_open);
        buffer.WriteULong(pos.magic_number);
        buffer.WriteDouble(pos.price_close);
        buffer.WriteInt(pos.close_reason);

        buffer.CopyBuffer(evTarget.data);
    }

    static void ToData(Event &evTarget, const CopyTradeReqData& src)
    {
        ByteBuffer buffer;
        buffer.WriteULong(src.server_ticket);
        buffer.WriteDouble(src.volume);
        buffer.WriteInt(src.position_type);
        buffer.WriteULong(src.target_ticket);
        buffer.WriteULong(src.tracking_number);

        buffer.CopyBuffer(evTarget.data);
    }
};