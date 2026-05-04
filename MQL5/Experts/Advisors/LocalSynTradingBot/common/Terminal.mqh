#include "Types.mqh"
#include "Constanst.mqh"
#include "Utils.mqh"

class Terminal
{
protected:
    Terminal() {}
    ~Terminal() {}

    EnumTerminalType m_TerminalType;

public:
    EnumTerminalType GetTerminalType()
    {
        return m_TerminalType;
    }

    virtual void OnRemote_Connecting() = 0;
    virtual void OnRemote_Connected(EnumTerminalType terminalType, double closedVolumeBySLSO, double alivePositionsVolume) = 0;
    virtual void OnRemote_OnSLSO(double closeVolumeBySLSO, double aliveVolume) = 0;
    virtual void OnRemote_Update(double closeVolumeBySLSO, double aliveVolume) = 0;
    virtual void OnRemote_Disconnected() = 0;

    virtual double GetAliveVolume() = 0;
    virtual double GetClosedVolumeBySLSO() = 0;

    virtual void ResetTradingSession() = 0;
    virtual void terminate() = 0;
};
