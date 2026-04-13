#include "Utils.mqh"
#include "LocalTerminal.mqh"
#include "RemoteTerminal.mqh"
#include "InOutController.mqh"

class AutoTpController
{
    LocalTerminal m_MyTerminal;
    RemoteTerminal m_RemoteTerminal;
    InOutController m_InOutController;

public:
    AutoTpController()
    {
    }
    ~AutoTpController()
    {
        Terminate();
    }

    void Init ()
    {
        m_MyTerminal.init(&m_InOutController, &m_RemoteTerminal);
        m_RemoteTerminal.init(&m_MyTerminal);
        m_InOutController.init(&m_RemoteTerminal, &m_MyTerminal);
    }

    void Terminate()
    {
        m_MyTerminal.terminate();
        m_RemoteTerminal.terminate();
        m_InOutController.terminate();
    }

    void OnTimer()
    {
        if (m_InOutController.GetState() == eREMOTE_STATE_RECONNECTING)
        {
            m_InOutController.DoReconnecting();
        }
        else if (m_InOutController.GetState() == eREMOTE_STATE_WAIT_INPUT)
        {
            m_InOutController.DoWaitInput();
        }
        else
        {
            m_InOutController.DoPoll();
        }
    }

    void OnLocal_OnTradeTransaction(const MqlTradeTransaction& trans,
                            const MqlTradeRequest& request,
                            const MqlTradeResult& result)
    {
        m_MyTerminal.OnLocal_OnTradeTransaction(trans, request, result);
    }
};