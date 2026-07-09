#include "IComparator.mqh"
template<typename T>
class List
{
private:
    T mList[];
    int mSize;
    IComparator<T>* mComparer;

public:
    List(IComparator<T>* comparer)
    {
        mComparer = comparer;
        mSize = 0;
        ArrayResize(mList, 0);
    }

    ~List()
    {
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
        ArrayResize(mList, mSize + 1);
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
        ArrayResize(mList, mSize);
        return true;
    }

    void Clear()
    {
        ArrayResize(mList, 0);
        mSize = 0;
    }

    int FindIndex(const T &obj) const
    {
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
