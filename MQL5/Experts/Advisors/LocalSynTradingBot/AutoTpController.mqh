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
        m_RemoteTerminal.termniate();
    }

    void OnTimer()
    {
        if (m_MyTerminal.GetRegistered() == false)
        {
            m_MyTerminal.DoRegister();
        }
        else
        {
            m_MyTerminal.SynUpLocalInfo();
            m_RemoteTerminal.DoPoll();
        }
    }
};