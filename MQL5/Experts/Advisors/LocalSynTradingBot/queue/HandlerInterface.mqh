#include "Event.mqh"

class iHandler
{
public:
    virtual void HandleEvent(const Event &ev) = 0;
    virtual void HandleEventDone(const Event &ev) = 0;
};