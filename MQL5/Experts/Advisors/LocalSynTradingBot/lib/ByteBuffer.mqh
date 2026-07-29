#include "../common/Logging.mqh"

class ByteBuffer
{
private:
    uchar   mBuffer[];
    int     mBufferSize;
    int     mReadPosition;
    struct DoubleHolder
    {
        double value;
    };

public:
    ByteBuffer()
    {
        mBufferSize = 0;
        mReadPosition = 0;
    }

    ByteBuffer(const uchar &byteArray[])
    {
        mBufferSize = ArraySize(byteArray);
        ArrayResize(mBuffer, mBufferSize);
        mReadPosition = 0;
        for (int i = 0; i < mBufferSize; i++)
        {
            mBuffer[i] = byteArray[i];
        }
    }

    void Clear()
    {
        ArrayResize(mBuffer, 0);
        mBufferSize = 0;
        mReadPosition = 0;
    }

    int Size()
    {
        return mBufferSize;
    }

    void CopyBuffer(uchar &arr[])
    {
        ArrayResize(arr, mBufferSize);
        ArrayCopy(arr, mBuffer, 0, 0, mBufferSize);
    }

    string ToString(const uchar &buffer[]) const
    {
        string hex = "Size=" + (string)mBufferSize + " [";
        for(int i = 0; i < mBufferSize; ++i)
        {
            hex += StringFormat("%02X", mBuffer[i]);
        }
        hex += "]";
        return hex;
    }

    /***********************************************************************
    *
    *    Write functions
    *
    ***********************************************************************/
    void WriteInt(const int value)
    {
        ArrayResize(mBuffer, mBufferSize+4);
        mBuffer[mBufferSize+0]=(uchar)(value);
        mBuffer[mBufferSize+1]=(uchar)(value>>8);
        mBuffer[mBufferSize+2]=(uchar)(value>>16);
        mBuffer[mBufferSize+3]=(uchar)(value>>24);
        mBufferSize += 4;
    }

    void WriteDouble(const double v)
    {
        DoubleHolder h;
        h.value = v;
        uchar tmp[];
        StructToCharArray(h,tmp);
        int old = mBufferSize;
        ArrayResize(mBuffer, old+8);
        ArrayCopy(mBuffer, tmp, old, 0, 8);
        mBufferSize += 8;
    }

    void WriteString(const string value)
    {
        uchar bytes[];
        StringToCharArray(value, bytes);
        // Bỏ ký tự '\0'
        int len = ArraySize(bytes);
        if(len > 0)
            len--;
        WriteInt(len);
        int old = mBufferSize;
        ArrayResize(mBuffer, old + len);
        ArrayCopy(mBuffer, bytes, old, 0, len);
        mBufferSize += len;
    }

    void WriteULong(const ulong value)
    {
        int old = mBufferSize;
        ArrayResize(mBuffer, old + 8);
        for(int i = 0; i < 8; i++)
        {
            mBuffer[old + i] = (uchar)(value >> (i * 8));
        }
        mBufferSize += 8;
    }

    void WriteBool(const bool value)
    {
        int old = mBufferSize;
        ArrayResize(mBuffer, old + 1);
        mBuffer[old] = value ? 1 : 0;
        mBufferSize += 1;
    }

    void WriteByteArray(const uchar &data[])
    {
        int len = ArraySize(data);
        WriteInt(len);
        int old = mBufferSize;
        ArrayResize(mBuffer, old + len);
        ArrayCopy(mBuffer, data, old, 0, len);
        mBufferSize += len;
    }

    void WriteByteArray(const uchar &data[], const int datalen)
    {
        WriteInt(datalen);
        int old = mBufferSize;
        ArrayResize(mBuffer, old + datalen);
        ArrayCopy(mBuffer, data, old, 0, datalen);
        mBufferSize += datalen;
    }

    /***********************************************************************
    *
    *    Read functions
    *
    ***********************************************************************/
    int ReadInt()
    {
        if (mReadPosition + 4 > mBufferSize)
        {
            LOGE("Error ReadInt: " + (string)mReadPosition + ", " + (string)mBufferSize);
            return 0;
        }
        int value=0;
        value |= mBuffer[mReadPosition++];
        value |= mBuffer[mReadPosition++]<<8;
        value |= mBuffer[mReadPosition++]<<16;
        value |= mBuffer[mReadPosition++]<<24;
        return value;
    }

    double ReadDouble()
    {
        if (mReadPosition + 8 > mBufferSize)
        {
            LOGE("Error ReadDouble: " + (string)mReadPosition + ", " + (string)mBufferSize);
            return 0;
        }
        uchar tmp[];
        ArrayResize(tmp,8);
        ArrayCopy(tmp, mBuffer, 0, mReadPosition, 8);
        DoubleHolder h;
        CharArrayToStruct(h, tmp);
        mReadPosition += 8;
        return h.value;
    }

    string ReadString()
    {
        int len = ReadInt();
        if(len <= 0)
            return "";
        if (mReadPosition + len > mBufferSize)
        {
            LOGE("Error ReadString: " + (string)mReadPosition + ", " + (string)len + ", " + (string)mBufferSize);
            return "";
        }
        uchar bytes[];
        ArrayResize(bytes, len);
        ArrayCopy(bytes, mBuffer, 0, mReadPosition, len);
        mReadPosition += len;
        return CharArrayToString(bytes);
    }

    ulong ReadULong()
    {
        if (mReadPosition + 8 > mBufferSize)
        {
            LOGE("Error ReadULong: " + (string)mReadPosition + ", " + (string)mBufferSize);
            return 0;
        }
        ulong value = 0;
        for(int i = 0; i < 8; i++)
        {
            value |= ((ulong)mBuffer[mReadPosition]) << (i * 8);
            mReadPosition++;
        }
        return value;
    }

    bool ReadBool()
    {
        if (mReadPosition + 1 > mBufferSize)
        {
            LOGE("Error ReadBool: " + (string)mReadPosition + ", " + (string)mBufferSize);
            return false;
        }
        uchar value = mBuffer[mReadPosition];
        mReadPosition++;
        return (value != 0);
    }

    void ReadByteArray(uchar &target[], int len)
    {
        if(len > 0)
        {
            if (mReadPosition + len > mBufferSize)
            {
                LOGE("Error ReadByteArray: " + (string)mReadPosition + ", " + (string)len + ", " + (string)mBufferSize);
                return;
            }
            ArrayResize(target, len);
            ArrayCopy(target, mBuffer, 0, mReadPosition, len);
            mReadPosition += len;
        }
    }
};