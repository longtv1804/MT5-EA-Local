#include <Trade\Trade.mqh>

enum EnumTerminalType {
    eTERMINAL_TYPE_UNKNOWN = 0,
    eTERMINAL_TYPE_XM = 1,
    eTERMINAL_TYPE_EXNESS = 2
};

enum EnumChangeType
{
    eCHANGE_TYPE_UNKNOWN = 0,
    eCHANGE_TYPE_OTHER,
    eCHANGE_TYPE_SL,
};

enum EnumCmdId
{
    eCMD_UNKNOWN,
    eCMD_DO_CONNECTING,
    eCMD_ON_CONNECTED,
    eCMD_ON_SLSO,
    eCMD_ON_UPDATE,
    eCMD_PING_ALIVE,
    eCMD_MAX
};

enum RemoteConnectionState
{
    eREMOTE_STATE_NOT_CONNECTED = 0,
    eREMOTE_STATE_CONNECTING,
    eREMOTE_STATE_CONNECTED,
};

enum EnumPositionStatus
{
    ePOSITION_STATUS_UNKNOWN = 0,    // default value, should not be used
    ePOSITION_STATUS_OPEN,
    ePOSITION_STATUS_CLOSED
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
    ENUM_DEAL_REASON      close_reason;
};
