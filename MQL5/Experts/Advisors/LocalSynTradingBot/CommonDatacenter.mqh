#include "Types.mqh"

class CommonDatacenter
{
private:
	CommonDatacenter() {}
	~CommonDatacenter() {}

public:
	static EnumTerminalType sLOCAL_TERMINAL_TYPE;
	static string sFILE_OUTPUT;
	static string sFILE_INPUT;


};

// Định nghĩa các biến static bên ngoài class
EnumTerminalType CommonDatacenter::sLOCAL_TERMINAL_TYPE = eTERMINAL_TYPE_UNKNOWN;
string CommonDatacenter::sFILE_OUTPUT = "";
string CommonDatacenter::sFILE_INPUT = "";