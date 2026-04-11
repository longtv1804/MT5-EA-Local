#include "Types.mqh"

class CommonDatacenter
{
private:
	CommonDatacenter() {}
	~CommonDatacenter() {}

public:
	static EnumTerminalType sLOCAL_TERMINAL_TYPE;
	static string sFile_REGISTER_FILE;
	static string sFILE_OUTPUT;
	static string sFILE_INPUT;

	static bool FEATURE_ENABLE_AUTO_TP_SL;
	static bool FEATURE_ENABLE_LOCAL_SYN;
};

// Định nghĩa các biến static bên ngoài class
EnumTerminalType CommonDatacenter::sLOCAL_TERMINAL_TYPE = eTERMINAL_TYPE_UNKNOWN;
string CommonDatacenter::sFile_REGISTER_FILE = "";
string CommonDatacenter::sFILE_OUTPUT = "";
string CommonDatacenter::sFILE_INPUT = "";
bool CommonDatacenter::FEATURE_ENABLE_AUTO_TP_SL = true;
bool CommonDatacenter::FEATURE_ENABLE_LOCAL_SYN = true;