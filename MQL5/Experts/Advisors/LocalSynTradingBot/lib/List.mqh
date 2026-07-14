#include "IComparator.mqh"
template<typename T>
class List
{
private:
    T mList[];
    int mCapacity;
    int mSize;
    IComparator<T>* mComparer;

public:
    List()
    {
        mComparer = NULL;
        mSize = 0;
        mCapacity = 2;
        ArrayResize(mList, mCapacity);
    }

    List(IComparator<T>* comparer)
    {
        mComparer = comparer;
        mSize = 0;
        mCapacity = 2;
        ArrayResize(mList, mCapacity);
    }

    ~List()
    {
        ArrayResize(mList, 0);
        if (mComparer)
        {
            delete mComparer;
        }
    }

    int Size() const
    {
        return mSize;
    }

    void Add(const T &obj)
    {
        if (mSize >= mCapacity)
        {
            mCapacity *= 2;
            ArrayResize(mList, mCapacity);
        }
        mList[mSize] = obj;
        mSize++;
    }

    bool Remove(const T &obj)
    {
        if(mComparer == NULL) return false;

        int index = FindIndex(obj);
        if(index < 0) return false;
        
        int i = 0;
        for(i = index; i < mSize - 1; i++)
        {
            mList[i] = mList[i + 1];
        }
        mSize--;
        return true;
    }

    bool Remove(const int idx)
    {
        if (idx < 0 || idx >= mSize) return false;

        for(int i = index; i < mSize - 1; i++)
        {
            mList[i] = mList[i + 1];
        }
        mSize--;
        return true;
    }

    void Clear()
    {
        ArrayResize(mList, 0);
        mSize = 0;
        mCapacity = 2;
        ArrayResize(mList, mCapacity);
    }

    int FindIndex(const T &obj) const
    {
        if(mComparer == NULL) return -1;

        for(int i = 0; i < mSize; i++)
        {
            if(mComparer.Equals(mList[i], obj))
                return i;
        }
        return -1;
    }

    bool Contains(const T &obj) const
    {
        if(mComparer == NULL) return false;
        for(int i = 0; i < mSize; i++)
        {
            if(mComparer.Equals(mList[i], obj))
            return true;
        }
        return false;
    }

    T* At(int index) const
    {
        if(index < 0 || index >= mSize)
        {
            return NULL;
        }
        return &mList[index];
    }
};
