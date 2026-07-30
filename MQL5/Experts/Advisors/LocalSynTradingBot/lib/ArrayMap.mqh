#include "List.mqh"

template <typename K, typename V>
class ArrayMap
{
private:
    List<K> mKeyList;
    List<V> mValueList;

public:
    ArrayMap() {}
    ~ArrayMap() {}

    void Add(const K &key, const V &value)
    {
        int idx = mKeyList.FindIndex(key);
        if (idx >= 0)
        {
            mValueList.OverrideValue(idx, value);
        }
        else
        {
            mKeyList.Add(key);
            mValueList.Add(value);
        }
    }

    bool ContainsKey(const K &key)
    {
        return mKeyList.FindIndex(key) >= 0;
    }

    V* At(const K &key)
    {
        int idx = mKeyList.FindIndex(key);
        if(idx < 0) return NULL;

        return mValueList.At(idx);
    }

    const V* At(const K &key) const
    {
        int idx = mKeyList.FindIndex(key);
        if(idx < 0) return NULL;

        return mValueList.At(idx);
    }

    bool TryGetValue(const K &key, V &value)
    {
        int idx = mKeyList.FindIndex(key);
        if(idx < 0)
            return false;

        value = mValueList.Get(idx);
        return true;
    }

    bool Remove(const K &key)
    {
        int idx = mKeyList.FindIndex(key);

        if(idx < 0)
            return false;

        mKeyList.RemoveAt(idx);
        mValueList.RemoveAt(idx);

        return true;
    }

    void Clear()
    {
        mKeyList.Clear();
        mValueList.Clear();
    }

    int Size() const
    {
        return mKeyList.Size();
    }
};