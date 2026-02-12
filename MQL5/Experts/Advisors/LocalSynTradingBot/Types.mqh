	
enum TerminalType {
   eTERMINAL_TYPE_LOCAL = 0,
   eTERMINAL_TYPE_REMOTE = 1
};

enum POSITION_TYPE
{
   ePOSITION_TYPE_BUY = 0,
   ePOSITION_TYPE_SELL = 1
};

enum DEAL_REASON
{
   eDEAL_REASON_SL = 1,
   eDEAL_REASON_TP = 2,
   eDEAL_REASON_CLIENT = 3
};

enum POSITON_STATUS
{
   ePOSITION_STATUS_OPEN,
   ePOSITION_STATUS_CLOSED
};

enum CLOSE_REASON
{
   eCLOSE_REASON_SL = eDEAL_REASON_SL,
   eCLOSE_REASON_TP = eDEAL_REASON_TP,
   eCLOSE_REASON_CLIENT = eDEAL_REASON_CLIENT,
   eCLOSE_REASON_UNKNOWN = -1
};

struct PositionInfo
{
   ulong    position_ticket;
   ulong    deal_ticket;
   string   symbol;
   POSITION_TYPE position_type;
   double   volume;
   double   price_open;
   double   price_close;
   datetime time_open;
   datetime time_close;
   POSITON_STATUS   status; 
   CLOSE_REASON   close_reason;  
};
