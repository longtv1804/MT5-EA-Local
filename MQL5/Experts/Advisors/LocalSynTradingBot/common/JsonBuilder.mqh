#include "../common/Types.mqh"
#include "../common/Utils.mqh"

class JsonBuilder
{
	string mJsonData[];

public:
	JsonBuilder()
	{
		ArrayResize(mJsonData, 0);
	}
	~JsonBuilder()
	{
		ArrayFree(mJsonData);
	}

	void Set(string key, string value)
	{
		string text = "\"" + key + "\":" + "\"" + value + "\"";
		int size = ArraySize(mJsonData);
		ArrayResize(mJsonData, size + 1);
		mJsonData[size] = text;
	}

	// void Set(string key, int value)
	// {
	// 	Set(key, (string)value);
	// }

	// void Set(string key, long value)
	// {
	// 	Set(key, (string)value);
	// }

	// void Set(string key, double value)
	// {
	// 	Set(key, (string)value);
	// }

	void Set(string key, iPosition& pos)
	{
		Set(key, ToJson(pos));
	}

	void Set(string key, iPosition& arr[])
	{
		int size = ArraySize(arr);
		string jsonData = "[";
		jsonData += "\"curent_positions\":[";
		for(int i = 0; i < size; i++)
		{
			jsonData += ToJson(arr[i]);
			if(i < size - 1)
				jsonData += ",";
		}
		jsonData += "]";
		Set(key, jsonData);
	}

	string Build()
	{
		string res = "{";
		int size = ArraySize(mJsonData);
		for(int i = 0; i < size; i++)
		{
			res += mJsonData[i];
			if(i < size - 1)
				res += ",";
		}
		res += "}";
		return res;
	}
};