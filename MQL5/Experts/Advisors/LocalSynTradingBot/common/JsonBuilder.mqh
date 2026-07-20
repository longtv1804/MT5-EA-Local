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

	void Set(const string key, const string value)
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

	void Set(const string key, const iPosition& pos)
	{
		string pos_jstr = ToJson(pos);
		string text = "\"" + key + "\":" + pos_jstr;
		int size = ArraySize(mJsonData);
		ArrayResize(mJsonData, size + 1);
		mJsonData[size] = text;
	}

	void Set(const string key, const iPosition& arr[])
	{
		int size = ArraySize(arr);
		string jsonData = "[";
		for(int i = 0; i < size; i++)
		{
			jsonData += ToJson(arr[i]);
			if(i < size - 1)
				jsonData += ",";
		}
		jsonData += "]";

		string text = "\"" + key + "\":" + jsonData;
		size = ArraySize(mJsonData);
		ArrayResize(mJsonData, size + 1);
		mJsonData[size] = text;
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