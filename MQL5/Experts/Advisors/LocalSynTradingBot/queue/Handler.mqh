class Event;

class Handler
{
public:
    virtual void HandleEvent(const Event &ev) = 0;
    virtual void HandleEventDone(const Event &ev) = 0;
};