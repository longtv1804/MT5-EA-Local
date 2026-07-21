#include "../common/Types.mqh"
class iHandler;

enum EnumEventState
{
    EVS_CREATED,
    EVS_QUEUED,
    EVS_DISPATCHING,
    EVS_DROP,
    EVS_DONE,
    EVS_FAILED,

    EVS_WAITING,
    EVS_WAIITING_SUCCESS,
    EVS_WAITING_FAILED,
    
    EVS_TIMEOUT
};

class Event
{
public:
    int eventId;
    EnumEventState state;
    int retry_count;
    datetime startTime;

    iHandler *handler;

    // với các dữ liệu đơn giản, ko phải struct, không phải array,...
    // dùng các arguments để lưu trữ và sử dụng
    // với các dữ liệu phức tạp hơn, hãy sử dụng data[]
    int     arg_int_1;
    int     arg_int_2;
    double  arg_double_1;
    double  arg_double_2;
    ulong   arg_ulong_1;
    ulong   arg_ulong_2;
    string  arg_string;

    // với các struct chỉ chứa dữ liệu primative
    //      có thể sử dụng 
    //              StructToCharArray(st, ev.data)      để chuyển đổi sang uchar
    //              CharArrayToStruct(ev.data, t_obj)   để chuyển đổi ngược lại struct
    // với các class hoặc struct chứa dữ liệu string/pointer/array cần phải viết chuyển đổi riêng
    // có thể sử dụng ByteBuffer
    uchar data[];

    Event()
    {
        Reset();
    }
    Event(const Event& src)
    {
       eventId      = src.eventId;
       state        = src.state;
       retry_count  = src.retry_count;
       startTime    = src.startTime;
       arg_int_1    = src.arg_int_1;
       arg_int_2    = src.arg_int_2;
       arg_double_1 = src.arg_double_1;
       arg_double_2 = src.arg_double_2;
       arg_ulong_1  = src.arg_ulong_1;
       arg_ulong_2  = src.arg_ulong_2;
       arg_string   = src.arg_string;
       handler      = src.handler;
       ArrayCopy(data, src.data);
    }

    void Reset()
    {
       eventId      = 0;
       state        = EVS_CREATED;
       retry_count  = 0;
       startTime    = 0;
       arg_int_1    = arg_int_2     = 0;
       arg_double_1 = arg_double_2  = 0.0;
       arg_ulong_1  = arg_ulong_2   = 0;
       arg_string   = "";
       handler      = NULL;
       ArrayResize(data, 0);
    }
};