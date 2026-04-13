#include "Terminal.mqh"
#include "CommonDatacenter.mqh"
#include "Types.mqh"
#include "Utils.mqh"

class RemoteTerminal : public Terminal
{
private:
    /*
    * lưu giá trị volume đã bị đóng bởi SL hoặc StopOut từ phía remote
    * và volume còn lại đang mở, để phục vụ cho việc tính toán logic auto TP ở local terminal.
    */
    double m_closedVolumeBySLSO;
    double m_alivePositionsVolume;

    Terminal* m_pLocalTerminal;

public:
    RemoteTerminal() : m_pLocalTerminal(NULL)
    {
        m_closedVolumeBySLSO = 0.0;
        m_alivePositionsVolume = 0.0;
    }

    ~RemoteTerminal() {}

    void init(Terminal* localTerminal) 
    {
        m_pLocalTerminal = localTerminal;
    }
    void terminate()
    {
    }
    double GetAliveVolume()
    {
        return m_alivePositionsVolume;
    }

    double GetClosedVolumeBySLSO()
    {
        return m_closedVolumeBySLSO;
    }

    void ResetTradingSession() override
    {
        m_closedVolumeBySLSO = 0.0;
        m_alivePositionsVolume = 0.0;
    }
    void OnRemote_Connecting() override
    {
        m_pLocalTerminal.OnRemote_Connecting();
    }

    void OnRemote_Connected(EnumTerminalType terminalType, double closedVolumeBySLSO, double alivePositionsVolume) override
    {
        m_TerminalType = terminalType;
        m_closedVolumeBySLSO = closedVolumeBySLSO;
        m_alivePositionsVolume = alivePositionsVolume;
        LOGD("remote connected: terminalType=" + ToString(terminalType) 
            + ", closedVolumeBySLSO=" + DoubleToString(closedVolumeBySLSO) 
            + ", alivePositionsVolume=" + DoubleToString(alivePositionsVolume));
        m_pLocalTerminal.OnRemote_Connected(terminalType, m_closedVolumeBySLSO, m_alivePositionsVolume);
    }

    void OnRemote_OnSLSO(double closeVolumeBySLSO, double aliveVolume) override
    {
        m_closedVolumeBySLSO = closeVolumeBySLSO;
        m_alivePositionsVolume = aliveVolume;
        m_pLocalTerminal.OnRemote_OnSLSO(closeVolumeBySLSO, aliveVolume);
    }

    void OnRemote_Update(double closeVolumeBySLSO, double aliveVolume) override
    {
        m_alivePositionsVolume = aliveVolume;
        m_closedVolumeBySLSO = closeVolumeBySLSO;
        m_pLocalTerminal.OnRemote_Update(closeVolumeBySLSO, aliveVolume);
    }

    void OnRemote_Disconnected() override
    {
        m_closedVolumeBySLSO = 0.0;
        m_alivePositionsVolume = 0.0;
        m_pLocalTerminal.OnRemote_Disconnected();
    }
};