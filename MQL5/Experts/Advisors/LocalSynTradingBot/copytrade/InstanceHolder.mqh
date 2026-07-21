class CPT_LocalTerminal;
class CPT_InOutManager;

class InstanceHolder
{
public:
    static CPT_LocalTerminal*  p_localTerminal;
    static CPT_InOutManager*   p_InOutMgr;

public:
    static CPT_LocalTerminal* GetLocalTerminal()
    {
        return p_localTerminal;
    }

    static CPT_InOutManager* GetInOutMgr()
    {
        return p_InOutMgr;
    }
};
CPT_LocalTerminal*  InstanceHolder::p_localTerminal     = NULL;
CPT_InOutManager*   InstanceHolder::p_InOutMgr          = NULL;
