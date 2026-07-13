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

    // command for auto TP tool
    eCMD_DO_CONNECTING,
    eCMD_ON_CONNECTED,
    eCMD_ON_SLSO,
    eCMD_ON_UPDATE,
    eCMD_PING_ALIVE,

    // command for copy trade
    eCMD_CPT_UPDATE,
    eCMD_CPT_POS_ADDED,
    eCMD_CPT_POS_CLOSED,

    // max numbber
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

enum EnumCopyTradeMode
{
    eCPT_MODE_UNKNOWN,
    eCPT_MODE_SERVER,
    eCPT_MODE_CLIENT
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

enum EnumSymbolType
{
    eSYMBOL_UNKNOWN,
    eSYMBOL_GOLD,
    eSYMBOL_BTC,
    eSYMBOL_ETH
};

class iPosition
{
public:
    ulong                position_ticket;
    string               symbol;
    EnumPositionType     position_type; // ePOSITION_TYPE_BUY, ePOSITION_TYPE_SELL, ...
    EnumPositionStatus   status;

    double               volume;
    double               price_open;
    ulong                magic_number;
    double               price_close;
    EnumCloseReason      close_reason;
};


/*********************************************************
*   Copy trade types
**********************************************************/
enum EventState
{
    EVS_QUEUED,         // đang chờ trong queue
    EVS_PROCESSING,     // đang chờ response
    EVS_FAILED,
    EVS_DONE,
    EVS_DROP
};

class CopyTradeEvent
{
public:
    int eventId;
    EventState status;
    int retry_count;
    int time_out;

    ulong server_ticket;

    double volume;
    EnumPositionType position_type;

    // với close: là ticket cần close, 
    // với add: sau khi đặt lệnh thảnh công thì lưu vào
    ulong target_ticket;

    // magic number để tracking lệnh thành công hay ko
    ulong tracking_number;
};

struct CopyTradeReqData
{
    ulong server_ticket;
    double volume;
    EnumPositionType position_type;

    // với close: là ticket cần close, 
    // với add: sau khi đặt lệnh thảnh công thì lưu vào
    ulong target_ticket;

    // magic number để tracking lệnh thành công hay ko
    ulong tracking_number;
};
