#define LOGD(msg) Print("\tD\t", __FUNCTION__, "\t", msg)
#define LOGE(msg) Print("\tE\t", __FUNCTION__, "\t", msg)

#include "Types.mqh"

//=======================================================================================
//
//	Json functions
//
//=======================================================================================
string ToString(iPosition &info)
{
	return StringFormat("[TICKET: %d - Symbol:%s - Type:%s - Status:%s - Volume:%.2f priceOpen:%.3f ]",
		info.position_ticket,
		info.symbol,
		PositionTypeToString(info.position_type),
		PositionStatusToString(info.status),
		info.volume,
		info.price_open
	);
}

string ToJson(const iPosition &info)
{
	string json = "{";
	json += "\"position_ticket\":" + IntegerToString(info.position_ticket) + ",";
	json += "\"symbol\":\"" + info.symbol + "\",";
	json += "\"position_type\":\"" + IntegerToString(info.position_type) + "\",";
	json += "\"status\":\"" + IntegerToString(info.status) + "\",";
	json += "\"volume\":" + DoubleToString(info.volume, 2) + ",";
	json += "\"price_open\":" + DoubleToString(info.price_open, 5) + ",";
	json += "}";
	return json;
}

string PositionTypeToString(int enumValue)
{
	switch(enumValue)
	{
		case OP_BUY:
			return "BUY";
		case OP_SELL:
			return "SELL";
		case OP_BUYLIMIT:
			return "BUYLIMIT";
		case OP_SELLLIMIT:
			return "SELLLIMIT";
		case OP_BUYSTOP:
			return "BUYSTOP";
		case OP_SELLSTOP:
			return "SELLSTOP";
		default:
			return "UNKNOWN";
	}
}
string PositionStatusToString(EnumPositionStatus status)
{
	switch(status)
	{
		case ePOSITION_STATUS_OPEN:
			return "OPEN";
		case ePOSITION_STATUS_CLOSED:
			return "CLOSED";
		default:
			return "UNKNOWN";
	}
}


//=======================================================================================
//
//	analyzing JSON functions
//
//=======================================================================================

// Hàm Trim loại bỏ khoảng trắng đầu/cuối chuỗi (thay thế StringTrim)
string Trim(const string str)
{
	int first = 0;
	int last = StringLen(str) - 1;
	while(first <= last && (StringGetCharacter(str, first) == ' ' || StringGetCharacter(str, first) == '\t')) first++;
	while(last >= first && (StringGetCharacter(str, last) == ' ' || StringGetCharacter(str, last) == '\t')) last--;
	if(first > last) return "";
	return StringSubstr(str, first, last - first + 1);
}

// Đơn giản lấy giá trị từ chuỗi json dạng "key":value hoặc "key":"value"
string GetJsonValue(const string json, const string key)
{
	string pattern = "\"" + key + "\":";
	int pos = StringFind(json, pattern);
	if(pos < 0) return "";
	int value_start = pos + StringLen(pattern);
	// Bỏ qua dấu cách
	while(StringGetCharacter(json, value_start) == ' ') value_start++;
	// Nếu là chuỗi
	int value_end = 0;
	if(StringGetCharacter(json, value_start) == '"')
	{
		value_start++;
		value_end = StringFind(json, "\"", value_start);
		if(value_end < 0) return "";
		return StringSubstr(json, value_start, value_end - value_start);
	}
	// Nếu là số hoặc giá trị không có dấu nháy
	value_end = StringFind(json, ",", value_start);
	if(value_end < 0)
		value_end = StringFind(json, "}", value_start);
	if(value_end < 0) return "";
	return Trim(StringSubstr(json, value_start, value_end - value_start));
}

// Lấy giá trị chuỗi từ json đơn giản: "key":"value"
string GetJsonString(const string json, const string key)
{
	string pattern = "\"" + key + "\":";
	int pos = StringFind(json, pattern);
	if(pos < 0) return "";
	int value_start = pos + StringLen(pattern);
	while(StringGetCharacter(json, value_start) == ' ') value_start++;
	if(StringGetCharacter(json, value_start) == '"')
	{
		value_start++;
		int value_end = StringFind(json, "\"", value_start);
		if(value_end < 0) return "";
		return StringSubstr(json, value_start, value_end - value_start);
	}
	return "";
}

// Static function: Parse a single JSON object to iPosition
iPosition ParseJsonToPosition(const string jsonObj)
{
	iPosition info;
	ZeroMemory(info);
	int fpos;
	fpos = StringFind(jsonObj, "\"position_ticket\":");
	if(fpos>=0) info.position_ticket = StringToInteger(GetJsonValue(jsonObj, "position_ticket"));
	fpos = StringFind(jsonObj, "\"symbol\":");
	if(fpos>=0) info.symbol = GetJsonString(jsonObj, "symbol");
	fpos = StringFind(jsonObj, "\"position_type\":");
	if(fpos>=0) info.position_type = StringToInteger(GetJsonValue(jsonObj, "position_type"));
	fpos = StringFind(jsonObj, "\"status\":");
	if(fpos>=0) info.status = (EnumPositionStatus)(StringToInteger(GetJsonValue(jsonObj, "status")));
	fpos = StringFind(jsonObj, "\"volume\":");
	if(fpos>=0) info.volume = StringToDouble(GetJsonValue(jsonObj, "volume"));
	fpos = StringFind(jsonObj, "\"price_open\":");
	if(fpos>=0) info.price_open = StringToDouble(GetJsonValue(jsonObj, "price_open"));
	return info;
}

// Static function: Parse JSON array to iPosition array
void ParseJsonArrayToPositions(const string jsonArr, iPosition &positions[])
{
	int pos = 0;
	while(pos < StringLen(jsonArr))
	{
		int obj_start = StringFind(jsonArr, "{", pos);
		if(obj_start < 0) break;
		int obj_end = StringFind(jsonArr, "}", obj_start);
		if(obj_end < 0) break;
		string obj = StringSubstr(jsonArr, obj_start, obj_end-obj_start+1);
		iPosition info = ParseJsonToPosition(obj);
		int n = ArraySize(positions);
		ArrayResize(positions, n+1);
		positions[n] = info;
		pos = obj_end+1;
	}
}

// lấy giá trị của key trong json string, nếu có.
string ParseJsonValue(const string json,const string key)
{
	string pattern="\""+key+"\":";
	int pos=StringFind(json,pattern);
	if(pos<0) return "";

	int value_start=pos+StringLen(pattern);

	// skip whitespace
	ushort c = 0;
	while(value_start<StringLen(json))
	{
		c=StringGetCharacter(json,value_start);
		if(c!=' ' && c!='\t' && c!='\n' && c!='\r')
			break;
		value_start++;
	}

	if(value_start>=StringLen(json))
		return "";

	ushort first=StringGetCharacter(json,value_start);

	// STRING
	if(first=='"')
	{
		value_start++;
		int value_end=StringFind(json,"\"",value_start);
		if(value_end>value_start)
		{
			return StringSubstr(json,value_start,value_end-value_start);
		}
	}

	// OBJECT
	int depth = 0;
	int i = 0;
	if(first=='{')
	{
		depth=1;
		i=value_start+1;

		while(i<StringLen(json) && depth>0)
		{
			c=StringGetCharacter(json,i);
			if(c=='{') depth++;
			if(c=='}') depth--;
			i++;
		}

		if(depth==0)
		{
			return StringSubstr(json,value_start,i-value_start);
		}
	}

	// ARRAY
	if(first=='[')
	{
		depth=1;
		i=value_start+1;

		while(i<StringLen(json) && depth>0)
		{
			c=StringGetCharacter(json,i);
			if(c=='[') depth++;
			if(c==']') depth--;
			i++;
		}

		if(depth==0)
			return StringSubstr(json,value_start,i-value_start);
	}

	// NUMBER / BOOL / NULL
	int idx=value_start;
	while(idx<StringLen(json))
	{
		c=StringGetCharacter(json,idx);
		if(c==',' || c=='}' || c==']')
			break;
		idx++;
	}

	if(idx>value_start)
	{
		return Trim(StringSubstr(json,value_start,i-value_start));
	}

	return "";
}

double ParseDoubleValue(const string json, const string key)
{
	string value_str = ParseJsonValue(json, key);
	if (value_str != "")
	{
		return StringToDouble(value_str);
	}
	else
	{
		LOGE("Key not found or value is empty: " + key + " in json: " + json);
	}
	return 0.0;
}

int ParseIntValue(const string json, const string key)
{
	string value_str = ParseJsonValue(json, key);
	if (value_str != "")
	{
		return StringToInteger(value_str);
	}
	else
	{
		LOGE("Key not found or value is empty: " + key + " in json: " + json);
	}
	return 0;
}

double GetTotalVolume(iPosition &arr[])
{
	double totalVolume = 0;
	for(int i = 0; i < ArraySize(arr); i++)
	{
		totalVolume += arr[i].volume; // volume is in lots
	}
	return totalVolume;
}

//=======================================================================================
//
//	Packaging JSON functions
//
//=======================================================================================

string PackageJson(EnumCmdId cmdId, iPosition &arr[])
{
	string jsonData = "{";
	jsonData += "\"cmd\":" + IntegerToString(cmdId) + ",";
	jsonData += "\"curent_positions\":[";
	for(int i = 0; i < ArraySize(arr); i++)
	{
		jsonData += ToJson(arr[i]);
		if(i < ArraySize(arr) - 1)
			jsonData += ",";
	}
	jsonData += "]}";
	return jsonData;
}

string PackageJson(EnumCmdId cmdId, string jsonData)
{
	jsonData = "{\"cmd\":" + IntegerToString(cmdId) + ",\"cmd_data\":" + jsonData + "}";
	return jsonData;
}