enum EnumTerminalType {
    eTERMINAL_TYPE_UNKNOWN = 0,
    eTERMINAL_TYPE_XM = 1,
    eTERMINAL_TYPE_EXNESS = 2,
    eTERMINAL_TYPE_FPG = 3
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
    eCMD_PING_A LIVE,
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
    int                  position_ticket;
    string               symbol;
    int                  position_type; // OP_BUY, OP_SELL, ...
    EnumPositionStatus   status;

    double               volume;
    double               price_open;
};
