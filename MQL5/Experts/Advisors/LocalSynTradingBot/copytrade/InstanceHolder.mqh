class CPT_LocalTerminal;
class CPT_SocketChannel;

class InstanceHolder
{
public:
    static CPT_LocalTerminal*  p_localTerminal;
    static CPT_SocketChannel*  p_channel;

public:
    static CPT_LocalTerminal* GetLocalTerminal()
    {
        return p_localTerminal;
    }

    static CPT_SocketChannel* GetChannel()
    {
        return p_channel;
    }
};
CPT_LocalTerminal*  InstanceHolder::p_localTerminal     = NULL;
CPT_SocketChannel*  InstanceHolder::p_channel           = NULL;
