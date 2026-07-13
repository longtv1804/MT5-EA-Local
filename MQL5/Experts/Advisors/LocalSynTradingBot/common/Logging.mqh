#define LOGD(msg) Print("D ", FormatFunctionName(__FUNCTION__), msg)
#define LOGE(msg) Print("E ", FormatFunctionName(__FUNCTION__), msg)

string FormatFunctionName(const string func)
{
    const int WIDTH = 50;
    int len = StringLen(func);

    if(len >= WIDTH)
       return func;

    string result = func;

    while(StringLen(result) < WIDTH)
       result += " ";

    return result;
}