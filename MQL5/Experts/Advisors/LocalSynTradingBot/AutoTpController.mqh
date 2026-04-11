#include "Utils.mqh"
#include "LocalTerminal.mqh"
#include "RemoteTerminal.mqh"

class AutoTpController
{
    LocalTerminal m_MyTerminal;
    RemoteTerminal m_RemoteTerminal;

public:
    AutoTpController()
    {
    }

    void Init ()
    {
        m_MyTerminal.init(&m_RemoteTerminal);
        m_RemoteTerminal.init(&m_MyTerminal);
    }

    void Terminate()
    {
        m_MyTerminal.terminate();
        m_RemoteTerminal.terminate();
    }

    void OnTimer()
    {
        if (m_RemoteTerminal.GetState() != eREMOTE_STATE_CONNECTED)
        {
            m_MyTerminal.DoConnect();
        }
        else
        {
            m_RemoteTerminal.DoPoll();
        }
    }

    void OnTradeTransaction(const MqlTradeTransaction& trans,
                            const MqlTradeRequest& request,
                            const MqlTradeResult& result)
    {
        m_MyTerminal.OnLocal_OnTradeTransaction(trans, request, result);
    }
};