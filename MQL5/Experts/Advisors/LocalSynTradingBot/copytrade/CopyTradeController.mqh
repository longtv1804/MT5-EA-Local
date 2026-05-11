#include "../common/Utils.mqh"
#include "../common/Types.mqh"
#include "../common/CommonDatacenter.mqh"
#include "CPT_LocalTerminal.mqh"
#include "CPT_ServerTerminal.mqh"
#include "CPT_ClientTerminal.mqh"
#include "CPT_InOutManager.mqh"
class CopyTradeController
{
    CPT_LocalTerminal* m_MyTerminal;
    CPT_InOutManager mInOutMgr;

public:
    CopyTradeController()
    {
    }

    ~CopyTradeController()
    {
        Terminate();
        if (m_MyTerminal)
        {
            delete m_MyTerminal;
            m_MyTerminal = NULL;
        }
    }

    bool Init(int terminal_mode, double weight)
    {
        CommonDatacenter::s_copyTradeMode = eCPT_MODE_UNKNOWN;
        if (terminal_mode == eCPT_MODE_SERVER)
        {
            CommonDatacenter::s_copyTradeMode = eCPT_MODE_SERVER;
            m_MyTerminal = new CPT_ServerTerminal();
        }
        else
        {
            CommonDatacenter::s_copyTradeMode = eCPT_MODE_CLIENT;
            m_MyTerminal = new CPT_ClientTerminal(weight);
        }

        bool isInitOk = false;
        
        isInitOk = m_MyTerminal.Init(&mInOutMgr);
        if (!isInitOk)
        {
            return false;
        }

        isInitOk = mInOutMgr.Init();
        return isInitOk;
    }

    void Terminate()
    {
        m_MyTerminal.Terminate();
        mInOutMgr.Terminate();
    }

    void OnTimer()
    {
        m_MyTerminal.DoPoll();
    }

    void OnLocal_OnTradeTransaction(const MqlTradeTransaction& trans,
                            const MqlTradeRequest& request,
                            const MqlTradeResult& result)
    {
        m_MyTerminal.OnLocal_OnTradeTransaction(trans, request, result);
    }
};