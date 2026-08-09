#include "../common/Terminal.mqh"
#include "../common/TerminalApi.mqh"
#include "../common/CommonDatacenter.mqh"
#include "../common/Types.mqh"
#include "../common/Utils.mqh"
#include "../queue/Handler.mqh"
#include "../lib/ByteBuffer.mqh"
#include "CPT_InOutManager.mqh"

class CPT_LocalTerminal : public Handler
{
protected:
    CPT_InOutManager *m_pInOutManager;

/**********************************************************************************
*
*  init/terminate function
*
***********************************************************************************/
public:
    CPT_LocalTerminal() 
    : Handler(),
    m_pInOutManager(NULL)
    {}

    ~CPT_LocalTerminal() {}

    virtual bool Init(CPT_InOutManager* inOutController)
    {
        m_pInOutManager = inOutController;
        return true;
    }

    virtual void Terminate() = 0;

/**********************************************************************************
*
*   OnLocal_OnTradeTransaction
*
***********************************************************************************/
public:
    virtual void OnPositionAdded(const iPosition& newPosition) {}
    virtual void OnPositionClosed(const iPosition& newPosition) {}

/**********************************************************************************
*
*  Poll
*
***********************************************************************************/
public:
    virtual void DoPoll() = 0;


/**********************************************************************************
*
*  for feature: revert copy trade positions
*
***********************************************************************************/
public:
    virtual void OnTimer() {}
    virtual bool InitStrategy(int planId) {return true;}
    virtual void SetStrategyParam(ByteBuffer& param) {}
    virtual void SetTotalStopLost(double sl) {}

/**********************************************************************************
*
*  for handler
*
***********************************************************************************/
public:
    virtual void HandleEvent(const Event &ev) override {}
    virtual void HandlePendingEventDone(const Event &ev) override {}
};