#include "../common/Types.mqh"
class iHandler;

class Event
{
public:
    Event()
    {
        Reset();
    }

    void Reset()
    {
       eventId = 0;
       state = EVS_CREATED;
       retry_count = 0;
       time_out = 0;
       arg1 = arg2 = 0;
       arg3 = 0.0;
       arg4 = 0;
       arg5 = "";
       handler = NULL;
       isReq = false;
    }

    int eventId;
    enum EnumEventState
    {
        EVS_CREATED,
        EVS_QUEUED,
        EVS_DISPATCHING,
        EVS_DROP,
        EVS_DONE,
        EVS_FAILED
    };
    EnumEventState state;
    bool isReq;
    int retry_count;
    int time_out;

    iHandler *handler;

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