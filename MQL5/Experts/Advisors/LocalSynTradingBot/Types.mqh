enum EnumTerminalType {
    eTERMINAL_TYPE_UNKNOWN = 0,
    eTERMINAL_TYPE_XM = 1,
    eTERMINAL_TYPE_EXNESS = 2,
    eTERMINAL_TYPE_FPG = 3
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

enum EnumChangeType
{
    eCHANGE_TYPE_UNKNOWN = 0,
    eCHANGE_TYPE_OTHER,
    eCHANGE_TYPE_SL,
};

struct iPosition
{
    int                  position_ticket;
    string               symbol;
    EnumPositionType     position_type; // ePOSITION_TYPE_BUY, ePOSITION_TYPE_SELL, ...
    EnumPositionStatus   status;

    double               volume;
    double               price_open;
};
