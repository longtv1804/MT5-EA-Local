enum EnumTerminalType {
    eTERMINAL_TYPE_UNKNOWN = 0,
    eTERMINAL_TYPE_XM = 1,
    eTERMINAL_TYPE_EXNESS = 2,
    eTERMINAL_TYPE_FPG = 3,
    eTERMINAL_TYPE_ULTIMA = 4,
    eTERMINAL_TYPE_PEPRE = 5,
    eTERMINAL_TYPE_VANTAGE = 6,
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
    eREMOTE_STATE_WAIT_INPUT,
    eREMOTE_STATE_CONNECTING,
    eREMOTE_STATE_CONNECTED,
    eREMOTE_STATE_RECONNECTING
};

/*********************************************************
*   Position info
**********************************************************/
enum EnumPositionStatus
{
    ePOSITION_STATUS_UNKNOWN = 0,    // default value, should not be used
    ePOSITION_STATUS_OPEN,
    ePOSITION_STATUS_CLOSED
};

enum EnumPositionType
{
    ePOSITION_TYPE_UNKNOWN = 0,    // default value, should not be used
    ePOSITION_TYPE_BUY,
    ePOSITION_TYPE_SELL
};

enum EnumCloseReason
{
    eCLOSE_REASON_UNKNOWN = 0,
    eCLOSE_REASON_USER,
    eCLOSE_REASON_SL,
    eCLOSE_REASON_SO,
    eCLOSE_REASON_TP,
    eCLOSE_REASON_OTHER
};

struct iPosition
{
    ulong                  position_ticket;
    string               symbol;
    EnumPositionType     position_type; // ePOSITION_TYPE_BUY, ePOSITION_TYPE_SELL, ...
    EnumPositionStatus   status;

    double               volume;
    double               price_open;
    double               price_close;
    EnumCloseReason      close_reason;
};
