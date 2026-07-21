#include "HandlerInterface.mqh"
#include "Event.mqh"
#include "../common/Logging.mqh"

const int MAX_QUEUE_SIZE = 50;

class EventQueue
{
private:
    Event mQueue[];
    int mInIdx;
    int mOutIdx;

    EventQueue()
    {
        ArrayResize(mQueue, MAX_QUEUE_SIZE);
        mInIdx = 0;
        mOutIdx = 0;
    }

    static EventQueue mInstance;

    const Event* DeQueue()
    {
        if (mInIdx == mOutIdx)
        {
            return NULL;
        }
        if (mOutIdx >= MAX_QUEUE_SIZE)
        {
            mOutIdx = 0;
        }
        return &mQueue[mOutIdx++];
    }

public:
    ~EventQueue()
    {
        ArrayResize(mQueue, 0);
    }

    static EventQueue* GetInstance()
    {
        return &mInstance;
    }

    void Execute()
    {
        if ((mInIdx - mOutIdx) == 0)
        {
            return;
        }
        const Event* ev = DeQueue();
        while (ev != NULL)
        {
            Event cpyEv = ev;
            if (cpyEv.state == EnumEventState::EVS_QUEUED)
            {
                cpyEv.state = EnumEventState::EVS_DISPATCHING;
                cpyEv.handler.HandleEvent(cpyEv);
            }
            else if (cpyEv.state == EnumEventState::EVS_DROP)
            {
                // ignore this event.
            }
            else
            {
                LOGE("ERROR: wrong event state: " + (string)cpyEv.state);
            }
            ev = DeQueue();
        }
    }

    void EnQueue(const Event &ev)
    {
        if (mInIdx >= MAX_QUEUE_SIZE)
        {
            mInIdx = 0;
            if (mInIdx == mOutIdx)
            {
                LOGE("Queue is full, ignore the event");
                return;
            }
        }
        mQueue[mInIdx] = ev;
        mQueue[mInIdx].state = EnumEventState::EVS_QUEUED;
        mInIdx++;
        if (mInIdx - mOutIdx == 1)
        {
            Execute();
        }
    }

    bool HasEvent(const int event_id, const iHandler* handler) const
    {
        if (mInIdx == mOutIdx)
        {
            return false;
        }
        for (int i = mOutIdx; i < mInIdx; i++)
        {
            if (mQueue[i].eventId == event_id && mQueue[i].handler == handler)
            {
                return true;
            }
        }
        return false;
    }

    bool TryIgnoreEvent(const int event_id, const iHandler* handler)
    {
        if (mInIdx == mOutIdx)
        {
            return false;
        }
        for (int i = mOutIdx; i < mInIdx; i++)
        {
            if (mQueue[i].eventId == event_id && mQueue[i].handler == handler)
            {
                mQueue[i].state = EnumEventState::EVS_DROP;
                return true;
            }
        }
        return false;
    }
};

EventQueue EventQueue::mInstance;