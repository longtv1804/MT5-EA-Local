#include "Event.mqh"
#include "HandlerInterface.mqh"
#include "EventQueue.mqh"

class Handler : public iHandler
{
public:
    Event ObtainEvent(const int eid, Handler* handler, const bool isReq = false)
    {
        Event ev;
        ev.eventId = eid;
        ev.handler = handler;
        ev.isReq = isReq;
        return ev;
    }

    Event ObtainEvent(const int eid, const bool isReq = false)
    {
        Event ev;
        ev.eventId = eid;
        ev.handler = this;
        ev.isReq = isReq;
        return ev;
    }

    void SendEvent(const Event& ev)
    {
        EventQueue::GetInstance().EnQueue(ev);
    }
};