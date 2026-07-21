#include "../common/Utils.mqh"
#include "../common/Logging.mqh"
#include "../common/Types.mqh"
#include "../common/Constants.mqh"
#include "../common/CommonDatacenter.mqh"
#include "../queue/EventQueue.mqh"
#include "../queue/PendingEventList.mqh"
#include "CPT_LocalTerminal.mqh"
#include "CPT_ServerTerminal.mqh"
#include "CPT_ClientTerminal.mqh"
#include "CPT_InOutManager.mqh"
#include "InstanceHolder.mqh"
class CopyTradeController
{
    CPT_LocalTerminal* m_MyTerminal;
    CPT_InOutManager mInOutMgr;
    bool mIsInitSuccessed;

public:
    CopyTradeController()
    {
        m_MyTerminal = NULL;
        mIsInitSuccessed = false;
    }

    ~CopyTradeController()
    {
        if (m_MyTerminal)
        {
            delete m_MyTerminal;
            m_MyTerminal = NULL;
        }
    }

    bool Init(int terminal_mode, double weight)
    {
        LOGD("EA: " + CPT_EA_VER);
        // init seed number for MathRand()
        MathSrand(GetTickCount());

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
        
        mIsInitSuccessed = m_MyTerminal.Init(&mInOutMgr);
        if (mIsInitSuccessed)
        {
            InstanceHolder::p_localTerminal = m_MyTerminal;
            InstanceHolder::p_InOutMgr = &mInOutMgr;
        }
        return mIsInitSuccessed;
    }

    void SetRevertPositionParam(bool isEnable, double slThreshold, double tpThreshold, int plan)
    {
        if (isEnable)
        {
            m_MyTerminal.SetRpEnable(isEnable);
            m_MyTerminal.SetRpThresholds(slThreshold, tpThreshold);
            m_MyTerminal.SetRpPlan(plan);
        }
    }

    void Terminate()
    {
        // chỉ khi init thành công mới save data
        if (m_MyTerminal && mIsInitSuccessed)
        {
            m_MyTerminal.Terminate();
        }

        // luôn luôn xóa file output
        mInOutMgr.Terminate();
    }

    void OnTimer()
    {
        // MQL5 có support OnTradeTransaction để detect position changed
        // MQL4 ko hỗ trợ, nên phải detect sự thay đổi của position theo từng timer.
#ifdef __MQL5__
        m_MyTerminal.DoPoll();
#else
        CheckLocalPositionChanged();
        m_MyTerminal.DoPoll();
#endif
        m_MyTerminal.OnTimer();
        PendingEventList::GetInstance().Execute();
        EventQueue::GetInstance().Execute();
    }
};