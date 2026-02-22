#include <Trade\Trade.mqh>

enum EnumTerminalType {
    eTERMINAL_TYPE_LOCAL = 0,
    eTERMINAL_TYPE_REMOTE = 1
};

enum EnumPositionStatus
{
    ePOSITION_STATUS_UNKNOWN = 0,    // default value, should not be used
    ePOSITION_STATUS_OPEN,
    ePOSITION_STATUS_CLOSED
};

enum EnumCloseReason
{
    eCLOSE_REASON_UNKNOWN = 0,
    eCLOSE_REASON_SL,
    eCLOSE_REASON_TP,
    eCLOSE_REASON_CLIENT,
};

struct iPosition
{
    ulong                position_ticket;
    ulong                deal_ticket;
    string               symbol;
    ENUM_POSITION_TYPE   position_type;
    EnumPositionStatus   status;

    double               volume;
    double               price_open;
    double               price_close;
    datetime             time_open;
    datetime             time_close;
    ENUM_POSITION_REASON open_reason;
    EnumCloseReason      close_reason;
};
