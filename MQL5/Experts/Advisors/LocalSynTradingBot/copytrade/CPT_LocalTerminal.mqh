#include "../common/Terminal.mqh"
#include "../common/TerminalApi.mqh"
#include "../common/CommonDatacenter.mqh"
#include "../common/Types.mqh"
#include "../common/Utils.mqh"
#include "CPT_InOutManager.mqh"

class CPT_LocalTerminal
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
    virtual void SetRevertPositionParam(bool isEnable, double slThreshold, double tpThreshold) {}
    virtual void Do_RP_CheckSLAndTP() {}
};