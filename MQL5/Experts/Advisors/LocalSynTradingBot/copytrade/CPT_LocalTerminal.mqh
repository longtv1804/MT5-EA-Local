#include "../common/Terminal.mqh"
#include "../common/TerminalApi.mqh"
#include "../common/CommonDatacenter.mqh"
#include "../common/Types.mqh"
#include "../common/Utils.mqh"
#include "../queue/Handler.mqh"
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
    CPT_LocalTerminal() : m_pInOutManager(NULL) {}

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
    virtual void OnPositionAdded(iPosition& newPosition) {}
    virtual void OnPositionClosed(iPosition& newPosition) {}

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
    virtual void SetRpEnable(bool isEnable) {}
    virtual void SetRpPlan(int rp_plan) {}
    virtual void SetRpThresholds(double slThreshold, double tpThreshold) {}

/**********************************************************************************
*
*  for handler
*
***********************************************************************************/
public:
    virtual void HandleEvent(const Event &ev) override {}
    virtual void HandlePendingEventDone(const Event &ev) override {}
};