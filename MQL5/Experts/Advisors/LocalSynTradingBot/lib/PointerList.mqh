template<typename T>
class PointerList
{
private:
    T* mList[];
    int mCapacity;
    int mSize;

public:
    PointerList()
    {
        mSize = 0;
        mCapacity = 2;
        ArrayResize(mList, mCapacity);
    }

    ~PointerList()
    {
    }

    int Size() const
    {
        return mSize;
    }

    void Add(T* ptr)
    {
        if (ptr == NULL)
        {
            return;
        }
        if (mSize >= mCapacity)
        {
            mCapacity *= 2;
            ArrayResize(mList, mCapacity);
        }
        mList[mSize] = ptr;
        mSize++;
    }

    bool Remove(const T* ptr)
    {
        return Remove(FindIndex(ptr));
    }

    bool Remove(const int idx)
    {
        if (idx < 0 || idx >= mSize) return false;
        for(int i = idx; i < mSize - 1; i++)
        {
            mList[i] = mList[i + 1];
        }
        mList[mSize-1]=NULL;
        mSize--;
        return true;
    }

    void Clear()
    {
        for(int i = 0; i < mSize; ++i)
            mList[i] = NULL;
        mSize = 0;
    }

    int FindIndex(const T* ptr) const
    {
        for(int i = 0; i < mSize; i++)
        {
            if(mList[i] == ptr) return i;
        }
        return -1;
    }

    bool Contains(const T* ptr) const
    {
        for(int i = 0; i < mSize; i++)
        {
            if(mList[i] == ptr) return true;
        }
        return false;
    }

    T* At(int index) const
    {
        if(index < 0 || index >= mSize)
        {
            return NULL;
        }
        return mList[index];
    }
};
