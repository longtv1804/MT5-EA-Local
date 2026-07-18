#include "../common/Types.mqh"
class iHandler;

class Event
{
public:
    int eventId;
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