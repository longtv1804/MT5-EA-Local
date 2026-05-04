#include "../common/Utils.mqh"
#include "CPD_LocalTerminal.mqh"
#include "CPD_RemoteTerminal.mqh"
#include "CPD_InOutManager.mqh"

class CopyTradeController
{
    CPD_LocalTerminal m_MyTerminal;
    CPD_RemoteTerminal m_RemoteTerminal;
    CPD_InOutManager m_InOutManager;

public:
    CopyTradeController()
    {
    }
    ~CopyTradeController()
    {
        Terminate();
    }

    void Init (int terminal_mode, double weight)
    {
        m_MyTerminal.init(&m_InOutManager, &m_RemoteTerminal);
        m_RemoteTerminal.init(&m_MyTerminal);
        m_InOutManager.init(&m_RemoteTerminal, &m_MyTerminal);
    }

    void Terminate()
    {
        m_MyTerminal.terminate();
        m_RemoteTerminal.terminate();
        m_InOutManager.terminate();
    }

    void OnTimer()
    {
        if (m_InOutManager.GetState() == eREMOTE_STATE_RECONNECTING)
        {
            m_InOutManager.DoReconnecting();
        }
        else if (m_InOutManager.GetState() == eREMOTE_STATE_WAIT_INPUT)
        {
            m_InOutManager.DoWaitInput();
        }
        else
        {
            m_InOutManager.DoPoll();
        }
    }

    void OnLocal_OnTradeTransaction(const MqlTradeTransaction& trans,
                            const MqlTradeRequest& request,
                            const MqlTradeResult& result)
    {
        m_MyTerminal.OnLocal_OnTradeTransaction(trans, request, result);
    }
};