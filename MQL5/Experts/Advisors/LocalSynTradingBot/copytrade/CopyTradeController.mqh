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
        // init seed number for MathRand()
        MathSrand(GetTickCount());

        // tạo local terminal instance: server or client
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

    bool SetStrategyPlan(int planId)
    {
        return m_MyTerminal.InitStrategy(planId);
    }

    void SetStrategyParam(double slThreshold, double tpThreshold)
    {
        m_MyTerminal.SetThresholds(slThreshold, tpThreshold);
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
        m_MyTerminal.DoPoll();
        m_MyTerminal.OnTimer();
        PendingEventList::GetInstance().Execute();
        EventQueue::GetInstance().Execute();
    }
};