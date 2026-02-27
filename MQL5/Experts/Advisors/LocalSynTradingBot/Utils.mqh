// Lấy giá trị chuỗi từ json đơn giản: "key":"value"
string GetJsonString(const string &json, const string &key)
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

#define LOGD(msg) Print("\tD\t", __FUNCTION__, "\t", msg)
#define LOGE(msg) Print("\tE\t", __FUNCTION__, "\t", msg)

#include <Trade/Trade.mqh>
#include "Types.mqh"

string ToString(iPosition &info)
{
	string status_str;
	switch(info.status)
	{
		case ePOSITION_STATUS_OPEN:
		status_str = "OPEN";
		break;
		case ePOSITION_STATUS_CLOSED:
		status_str = "CLOSED";
		break;
		default:
		status_str = "UNKNOWN";
	}
	string close_time_str = (info.status == ePOSITION_STATUS_CLOSED) ? TimeToString(info.time_close) : "--:--";
	string close_price_str = (info.status == ePOSITION_STATUS_CLOSED) ? DoubleToString(info.price_close, _Digits) : "--";
	string close_reason_str = (info.status == ePOSITION_STATUS_CLOSED) ? EnumToString(info.close_reason) : "--";
	return StringFormat("[TICKET: %d - Symbol:%s - Type:%s - Status:%s - Volume:%.2f | PriceOpen:%.5f - TimeOpen:%s - OpenReason:%s | PriceClose:%s - CloseTime:%s - CloseReason:%s(%d) ]",
		info.position_ticket,
		info.symbol,
		EnumToString(info.position_type),
		status_str,
		info.volume,
		info.price_open,
		TimeToString(info.time_open),
		EnumToString(info.open_reason),
		close_price_str,
		close_time_str,
		close_reason_str,
		info.close_reason
	);
}

string ToSimpleString(iPosition &info)
{
	string status_str;
	switch(info.status)
	{
		case ePOSITION_STATUS_OPEN:
		status_str = "OPEN";
		break;
		case ePOSITION_STATUS_CLOSED:
		status_str = "CLOSED";
		break;
		default:
		status_str = "UNKNOWN";
	}
	string close_price_str = (info.status == ePOSITION_STATUS_CLOSED) ? DoubleToString(info.price_close, _Digits) : "--";
	return StringFormat("[ TICKET: %d - Symbol:%s - Type:%s - Status:%s - Volume:%.2f - PriceOpen:%.5f - PriceClose:%s ]",
		info.position_ticket,
		info.symbol,
		EnumToString(info.position_type),
		status_str,
		info.volume,
		info.price_open,
		close_price_str
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
	json += "\"time_open\":\"" + TimeToString(info.time_open, TIME_DATE|TIME_SECONDS) + "\",";
	json += "\"open_reason\":\"" + IntegerToString(info.open_reason) + "\",";
	json += "}";
	return json;
}

string ToString(const MqlTradeTransaction& trans)
{
	return StringFormat(
		"TRANS=[ Symbol:%s|type=%s|order=%I64u|deal=%I64u|position=%I64u|position_by=%I64u|price=%.5f|volume=%.2f|order_type=%s|deal_type=%s ]",
		trans.symbol,
		EnumToString(trans.type),
		trans.order,
		trans.deal,
		trans.position,
		trans.position_by,
		trans.price,
		trans.volume,
		EnumToString(trans.order_type),
		EnumToString(trans.deal_type)
	);
}

string ToString(const MqlTradeRequest& request)
{
return StringFormat(
	"REQUEST=[symbol=%s|action=%d|magic=%I64d|order=%I64d|position_by=%I64d|volume=%.2f|price=%.5f|sl=%.5f|tp=%.5f|type=%s|type_filling=%s|type_time=%s|deviation=%d|position_ticket=%I64d|expiration=%s|comment=%s]",
	request.symbol,
	request.action,
	request.magic,
	request.order,
	request.position_by,
	request.volume,
	request.price,
	request.sl,
	request.tp,
	EnumToString(request.type),
	EnumToString(request.type_filling),
	EnumToString(request.type_time),
	request.deviation,
	request.position,
	TimeToString(request.expiration, TIME_DATE|TIME_SECONDS),
	request.comment
);
}

string ToString(const MqlTradeResult& result)
{
   return StringFormat(
		"RESULT=[retcode=%d|deal=%I64d|order=%I64d|volume=%.2f|price=%.5f|bid=%.5f|ask=%.5f|request_id=%I64d|retcode_external=%d|comment=%s]",
		result.retcode,
		result.deal,
		result.order,
		result.volume,
		result.price,
		result.bid,
		result.ask,
		result.request_id,
		result.retcode_external,
		result.comment
	);
}



// Hàm Trim loại bỏ khoảng trắng đầu/cuối chuỗi (thay thế StringTrim)
string Trim(const string &str)
{
	int first = 0;
	int last = StringLen(str) - 1;
	while(first <= last && (StringGetCharacter(str, first) == ' ' || StringGetCharacter(str, first) == '\t')) first++;
	while(last >= first && (StringGetCharacter(str, last) == ' ' || StringGetCharacter(str, last) == '\t')) last--;
	if(first > last) return "";
	return StringSubstr(str, first, last - first + 1);
}
// Đơn giản lấy giá trị từ chuỗi json dạng "key":value hoặc "key":"value"
string GetJsonValue(const string &json, const string &key)
{
	string pattern = "\"" + key + "\":";
	int pos = StringFind(json, pattern);
	if(pos < 0) return "";
	int value_start = pos + StringLen(pattern);
	// Bỏ qua dấu cách
	while(StringGetCharacter(json, value_start) == ' ') value_start++;
	// Nếu là chuỗi
	if(StringGetCharacter(json, value_start) == '"')
	{
		value_start++;
		int value_end = StringFind(json, "\"", value_start);
		if(value_end < 0) return "";
		return StringSubstr(json, value_start, value_end - value_start);
	}
	// Nếu là số hoặc giá trị không có dấu nháy
	int value_end = StringFind(json, ",", value_start);
	if(value_end < 0)
		value_end = StringFind(json, "}", value_start);
	if(value_end < 0) return "";
	return Trim(StringSubstr(json, value_start, value_end - value_start));
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