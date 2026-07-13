#include "Handler.mqh"
#include "../common/Types.mqh"

class Event
{
public:
    int eventId;
    enum EnumEventState
    {
        EVS_QUEUED,
        EVS_DISPATCHING,
        EVS_DROP,
        EVS_DONE,
        EVS_FAILED
    };
    EnumEventState state;
    int retry_count;
    int time_out;

    Handler *handler;

    // với các dữ liệu đơn giản, ko phải struct, không phải array,...
    // dùng các arguments để lưu trữ và sử dụng
    // với các dữ liệu phức tạp hơn, hãy sử dụng data[]
    int     arg1;
    int     arg2;
    double  arg3;
    ulong   arg4;
    string  arg5;

    // với các struct chỉ chứa dữ liệu primative
    //      có thể sử dụng 
    //              StructToCharArray(st, ev.data)      để chuyển đổi sang uchar
    //              CharArrayToStruct(ev.data, t_obj)   để chuyển đổi ngược lại struct
    // với các class hoặc struct chứa dữ liệu string/pointer/array cần phải viết chuyển đổi riêng
    // có thể sử dụng ByteBuffer
    uchar data[];
};