#include "Event.mqh"
#include "HandlerInterface.mqh"
#include "../lib/List.mqh"

class PendingEventList
{
private:
    List<Event> mPendingList;
    static PendingEventList mIns;
    PendingEventList() {}

public:
    ~PendingEventList()
    {
        mPendingList.Clear();
    }

    static PendingEventList* GetInstance()
    {
        return &mIns;
    }

    void Execute()
    {
        int i = 0;
        int size = mPendingList.Size();
        datetime now = TimeCurrent();
        const int PENDING_EVNT_TIMEOUT = 10;
        Event copiedEv;
        while (i < size)
        {
            if (mPendingList.At(i).state == Event::EVS_WAIITING_SUCCESS ||
                mPendingList.At(i).state == Event::EVS_WAITING_FAILED)
            {
                copiedEv = *(mPendingList.At(i));
                copiedEv.handler.HandlePendingEventDone(copiedEv);
                mPendingList.Remove(i);
                size = mPendingList.Size();
            }
            else
            {
                if (now - mPendingList.At(i).startTime >= PENDING_EVNT_TIMEOUT)
                {
                    mPendingList.At(i).state = Event::EVS_TIMEOUT;
                    copiedEv = *(mPendingList.At(i));
                    copiedEv.handler.HandlePendingEventDone(copiedEv);
                    mPendingList.Remove(i);
                    size = mPendingList.Size();
                }
                else
                {
                    i++;
                }
            }
        }
    }

    void AddEvent(const Event& ev)
    {
        mPendingList.Add(ev);
        mPendingList.At(mPendingList.Size() - 1).state      = Event::EVS_WAITING;
        mPendingList.At(mPendingList.Size() - 1).startTime   = TimeCurrent();
    }

    int Size() const
    {
        return mPendingList.Size();
    }

    Event* At(int idx)
    {
        return mPendingList.At(idx);
    }
};
PendingEventList PendingEventList::mIns;