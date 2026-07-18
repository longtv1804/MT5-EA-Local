#include "Event.mqh"
#include "HandlerInterface.mqh"
#include "EventQueue.mqh"
#include "PendingEventList.mqh"

class Handler : public iHandler
{
public:
    Event ObtainEvent(const int eid, Handler* handler)
    {
        Event ev;
        ev.eventId = eid;
        ev.handler = handler;
        return ev;
    }

    Event ObtainEvent(const int eid)
    {
        Event ev;
        ev.eventId = eid;
        ev.handler = this;
        return ev;
    }

    void SendEvent(const Event& ev)
    {
        EventQueue::GetInstance().EnQueue(ev);
    }

    void SendPendingEvent(const Event& ev)
    {
        PendingEventList::GetInstance().AddEvent(ev);
    }
};