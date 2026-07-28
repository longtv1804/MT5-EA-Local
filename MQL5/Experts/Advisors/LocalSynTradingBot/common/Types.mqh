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

enum EnumStrategyPositionType
{
    eSPT_BUY = 1,
    eSPT_SELL,
    eSPT_BUY_SELL
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
    iPosition()
    {
        position_ticket = 0;
        symbol = "";
        position_type = 0;
        status = 0;
        volume = 0;
        price_open = 0;
        magic_number = 0;
        price_close = 0;
        close_reason = 0;
    }
    iPosition(const iPosition& src)
    {
        position_ticket = src.position_ticket;
        symbol = src.symbol;
        position_type = src.position_type;
        status = src.status;
        volume = src.volume;
        price_open = src.price_open;
        magic_number = src.magic_number;
        price_close = src.price_close;
        close_reason = src.close_reason;
    }
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
enum EnumCopyTradeEvent
{
    EV_ADD_NEW_POSITION = 1,
    EV_ADD_NEW_POSITION_DONE,
    EV_CLOSED_POSITION,
    EV_CLOSED_POSITION_DONE,
    
    EV_PENDING_CLOSE_NOT_ADDED_POSITION,
    EV_PENDING_WAITING_NEW_POSITION,
    EV_PENDING_WAITING_CLOSE_POSITION,

    EV_STRATEGY_UPDATE_PARAMS,
    EV_STRATEGY_CLOSE_ALL_POSITIONS_WITHOUT_SERVER_TRIGGER
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

enum EnumStrategyPlanId {
    PLAN_ID_1 = 1,      /*PLAN-1: Open position follow Master*/
    PLAN_ID_2 = 2,      /*PLAN-2: Dragdown volume: 0.13, 0.08, 0.05,..*/
    PLAN_ID_3 = 3,      /*PLAN-3: Open position start from i'th order*/
    PLAN_ID_4 = 4,      /*PLAN-4: StopLost at i'th order*/
    PLAN_ID_5 = 5,      /*PLAN-5: Revert Copy trade*/
    PLAN_ID_MAX
};