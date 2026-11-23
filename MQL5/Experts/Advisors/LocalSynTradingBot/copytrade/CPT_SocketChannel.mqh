//+------------------------------------------------------------------+
//|                                          CPT_SocketChannel.mqh |
//|  Kênh trao đổi dữ liệu giữa SERVER terminal và CLIENT terminal  |
//|  bằng local socket TCP (127.0.0.1) - thay cho cơ chế file .dat    |
//|                                                                  |
//|  Nguyên tắc hoạt động (giống hệt bản file, chỉ đổi "transport"): |
//|   - SERVER: mở cổng lắng nghe, broadcast mọi bản tin JSON ra      |
//|             tất cả client.                                        |
//|   - CLIENT: kết nối tới server, gửi HELLO (client_id) ngay khi    |
//|             kết nối, sau đó đọc bản tin và lọc theo "to_client". |
//|   - Mỗi bản tin là 1 dòng JSON kết thúc bằng '\n'.               |
//|   - Phát hiện server "đã tồn tại" / mất kết nối tương ứng với    |
//|     phần kiểm tra file của bản cũ.                                |
//+------------------------------------------------------------------+
#ifndef LOCALSYN_CPT_SOCKET_CHANNEL_MQH
#define LOCALSYN_CPT_SOCKET_CHANNEL_MQH

#include "../lib/WinSocket.mqh"
#include "../common/Types.mqh"
#include "../common/Constants.mqh"
#include "../common/Utils.mqh"
#include "../common/Logging.mqh"
#include "../common/JsonBuilder.mqh"
#include "../common/TerminalApi.mqh"
#include "../common/CommonDatacenter.mqh"

//---- giới hạn của kênh socket ---------------------------------------
#define CPT_SOCK_MAX_CLIENT     5           // = MAX_CLIENT
#define CPT_SOCK_RECV_INIT      16384       // buffer nhận ban đầu (16KB)
#define CPT_SOCK_RECV_MAX       1048576     // buffer nhận tối đa (1MB)
#define CPT_SOCK_TMP_BUF        8192        // buffer đọc tạm mỗi lần recv

//+------------------------------------------------------------------+
//| CPT_SockPeer: 1 kết nối socket + buffer nhận của nó              |
//+------------------------------------------------------------------+
class CPT_SockPeer
{
public:
    long    mSock;
    int     mId;               // client_id (0 nếu chưa HELLO)
    bool    mHello;            // đã nhận HELLO?
    bool    mDead;             // kết nối hỏng / chủ động đóng
    uchar   mBuf[];            // dữ liệu nhận dở (chưa đủ 1 dòng)
    int     mLen;              // số byte thực sự trong mBuf

    CPT_SockPeer()
    {
        mSock   = CS_INVALID_SOCKET;
        mId     = 0;
        mHello  = false;
        mDead   = false;
        mLen    = 0;
        ArrayResize(mBuf, CPT_SOCK_RECV_INIT);
    }

    CPT_SockPeer(const long sock)
    {
        mSock   = sock;
        mId     = 0;
        mHello  = false;
        mDead   = false;
        mLen    = 0;
        ArrayResize(mBuf, CPT_SOCK_RECV_INIT);
    }

    ~CPT_SockPeer()
    {
        WinSocket::CloseSock(mSock);
    }

    bool IsOpen()
    {
        return (mSock != CS_INVALID_SOCKET) && !mDead;
    }

    //------------------------------------------------------------------
    // cộng dồn byte vào buffer nhận
    //------------------------------------------------------------------
    void Append(const uchar &chunk[], const int size)
    {
        if (size <= 0 || mDead)
        {
            return;
        }
        if (mLen + size > CPT_SOCK_RECV_MAX)
        {
            LOGE("recv buffer overflow (" + (string)CPT_SOCK_RECV_MAX + " byte), drop connection");
            mDead = true;
            return;
        }
        if (mLen + size > ArraySize(mBuf))
        {
            ArrayResize(mBuf, mLen + size + 4096);
        }
        for (int i = 0; i < size; i++)
        {
            mBuf[mLen + i] = chunk[i];
        }
        mLen += size;
    }

    //------------------------------------------------------------------
    // đọc hết dữ liệu đang có rồi trích ra các dòng JSON hoàn chỉnh
    //   return: số dòng trích được (append vào out)
    //   nếu bên kia đóng kết nối -> mDead = true
    //------------------------------------------------------------------
    int ReadMessages(string &out[])
    {
        ArrayResize(out, 0);
        if (!IsOpen())
        {
            return 0;
        }

        // 1. đọc hết dữ liệu đang tới
        uchar tmp[CPT_SOCK_TMP_BUF];
        while (true)
        {
            int n = WinSocket::RecvData(mSock, tmp, CPT_SOCK_TMP_BUF);
            if (n > 0)
            {
                Append(tmp, n);
                if (mDead)
                {
                    return ArraySize(out);
                }
                continue;
            }
            if (n < 0)
            {
                mDead = true;      // server/peer đóng kết nối
                return ArraySize(out);
            }
            break;                  // 0: hết dữ liệu
        }

        // 2. trích các dòng kết thúc bằng '\n'
        int count = 0;
        int start = 0;
        for (int i = 0; i < mLen; i++)
        {
            if (mBuf[i] != 0x0A)
            {
                continue;
            }
            int len = i - start;
            if (len > 0 && mBuf[i - 1] == 0x0D)    // bỏ '\r'
            {
                len--;
            }
            if (len > 0)
            {
                string line = CharArrayToString(mBuf, start, len, CP_UTF8);
                if (StringLen(line) > 0)
                {
                    ArrayResize(out, count + 1);
                    out[count] = line;
                    count++;
                }
            }
            start = i + 1;
        }

        // 3. giữ lại phần dữ liệu dở
        if (start > 0)
        {
            for (int i = 0; i < mLen - start; i++)
            {
                mBuf[i] = mBuf[start + i];
            }
            mLen -= start;
        }
        return count;
    }

    //------------------------------------------------------------------
    // xóa dữ liệu cũ (tương ứng SeekToEndInputFile của bản file)
    //------------------------------------------------------------------
    void ClearBuffer()
    {
        mLen = 0;
    }
};

//+------------------------------------------------------------------+
//| CPT_SocketChannel: kênh giao tiếp socket                          |
//+------------------------------------------------------------------+
class CPT_SocketChannel
{
private:
    ushort          mPort;
    int             mId;            // client_id (client mode)
    long            mListenSock;    // server: socket lắng nghe
    bool            mListening;
    CPT_SockPeer*   mPeers[CPT_SOCK_MAX_CLIENT];    // server: các client
    int             mPeerCount;
    CPT_SockPeer*   mServer;        // client: kết nối tới server

    bool IsServerMode()
    {
        return CommonDatacenter::s_copyTradeMode == eCPT_MODE_SERVER;
    }

    bool IsClientMode()
    {
        return CommonDatacenter::s_copyTradeMode == eCPT_MODE_CLIENT;
    }

    //------------------------------------------------------------------
    // client_id ngẫu nhiên (khác 0)
    //   - dùng dải số lớn (MathRand() x 65536 + MathRand()) để 2 client
    //     khó mà trùng id nhau (trùng id -> bản tin "to_client" bị nhận nhầm)
    //------------------------------------------------------------------
    int MakeClientId()
    {
        int id = (MathRand() * 65536) + MathRand();
        if (id <= 0)
        {
            id = (int)(GetTickCount() % 1000000) + 1;
        }
        return id;
    }

    //------------------------------------------------------------------
    // SERVER
    //------------------------------------------------------------------
    bool OpenAsServer()
    {
        if (mListening)
        {
            return true;
        }

        // đã có server khác đang listen cổng này -> báo lỗi và đóng EA
        // (tương ứng bản file: file CPT_server.dat đã tồn tại)
        long probe = WinSocket::ConnectTo(mPort);
        if (probe != CS_INVALID_SOCKET)
        {
            WinSocket::CloseSock(probe);
            TerminalAPI::DoShowMessagePopup("SERVER is already existed, close EA!!!");
            TerminalAPI::DoCloseEA();
            return false;
        }

        if (!WinSocket::Listen(mPort, mListenSock))
        {
            TerminalAPI::DoShowMessagePopup("Can not listen on port " + (string)mPort + ", close EA!!!");
            TerminalAPI::DoCloseEA();
            return false;
        }
        mListening = true;
        LOGD("SERVER is listening on 127.0.0.1:" + (string)mPort);
        return true;
    }

    //------------------------------------------------------------------
    // CLIENT
    //------------------------------------------------------------------
    bool OpenAsClient()
    {
        if (mServer != NULL && mServer.IsOpen())
        {
            return true;                    // đã kết nối
        }

        // mỗi lần kết nối 1 client_id mới -> server luôn coi đây là client mới
        mId = MakeClientId();

        long sock = WinSocket::ConnectTo(mPort);
        if (sock == CS_INVALID_SOCKET)
        {
            return false;                   // server chưa chạy
        }

        if (mServer != NULL)
        {
            delete mServer;
        }
        mServer = new CPT_SockPeer(sock);

        // gửi HELLO để server đăng ký client_id
        JsonBuilder builder;
        builder.Set("cmd", (string)eCMD_CPT_HELLO);
        builder.Set("client_id", (string)mId);
        if (!WinSocket::SendLine(sock, builder.Build()))
        {
            LOGE("can not send HELLO to server");
            delete mServer;
            mServer = NULL;
            return false;
        }
        LOGD("connected to server 127.0.0.1:" + (string)mPort + " as Client[" + (string)mId + "]");
        return true;
    }

    //------------------------------------------------------------------
    // SERVER: xử lý 1 dòng dữ liệu nhận được từ client
    //------------------------------------------------------------------
    void HandlePeerLine(CPT_SockPeer* peer, const string line)
    {
        int cmd = ParseIntValue(line, "cmd");
        if (cmd == eCMD_CPT_HELLO)
        {
            int id = ParseIntValue(line, "client_id");
            if (id <= 0)
            {
                LOGE("invalid HELLO, drop connection: " + line);
                peer.mDead = true;
                return;
            }
            if (peer.mHello && peer.mId != id)
            {
                LOGD("Client[" + (string)peer.mId + "] re-registered as [" + (string)id + "]");
            }
            peer.mId = id;
            peer.mHello = true;
            LOGD("Hello from Client[" + (string)id + "]");
            return;
        }

        // phiên bản này client không gửi dữ liệu lên server -> bỏ qua
        LOGD("ignore client msg: " + line);
    }

    //------------------------------------------------------------------
    // SERVER: accept kết nối mới, đọc dữ liệu, dọn kết nối hỏng
    //------------------------------------------------------------------
    void PumpAsServer()
    {
        if (!mListening)
        {
            return;
        }

        // 1. accept kết nối mới
        while (true)
        {
            long s = WinSocket::AcceptNew(mListenSock);
            if (s == CS_INVALID_SOCKET)
            {
                break;                      // hết kết nối chờ
            }
            if (mPeerCount >= CPT_SOCK_MAX_CLIENT)
            {
                LOGE("reach MAX_CLIENT, reject new connection");
                WinSocket::CloseSock(s);
                continue;
            }
            mPeers[mPeerCount] = new CPT_SockPeer(s);
            mPeerCount++;
            LOGD("new connection accepted (" + (string)mPeerCount + " peer(s))");
        }

        // 2. đọc dữ liệu từ từng client
        for (int i = 0; i < mPeerCount; i++)
        {
            if (mPeers[i] == NULL)
            {
                continue;
            }
            string lines[];
            mPeers[i].ReadMessages(lines);
            for (int j = 0; j < ArraySize(lines); j++)
            {
                HandlePeerLine(mPeers[i], lines[j]);
            }
        }

        // 3. dọn kết nối hỏng
        int writeIdx = 0;
        for (int i = 0; i < mPeerCount; i++)
        {
            CPT_SockPeer* p = mPeers[i];
            if (p == NULL)
            {
                continue;
            }
            if (!p.IsOpen())
            {
                if (p.mHello)
                {
                    LOGD("missing Client[" + (string)p.mId + "]");
                }
                delete p;
                continue;
            }
            mPeers[writeIdx] = p;
            writeIdx++;
        }
        for (int i = writeIdx; i < mPeerCount; i++)
        {
            mPeers[i] = NULL;
        }
        mPeerCount = writeIdx;
    }

public:
    CPT_SocketChannel()
    {
        mPort       = 0;
        mId         = 0;
        mListenSock = CS_INVALID_SOCKET;
        mListening  = false;
        mPeerCount  = 0;
        mServer     = NULL;
        for (int i = 0; i < CPT_SOCK_MAX_CLIENT; i++)
        {
            mPeers[i] = NULL;
        }
    }

    ~CPT_SocketChannel()
    {
        Close();
    }

    void SetPort(const ushort port)
    {
        mPort = (port > 0 ? port : CPT_DEFAULT_SOCKET_PORT);
    }

    /**********************************************************************************
    *
    *   init/terminate - tương ứng InitFilesPath()/Init()/Terminate() của bản file
    *
    ***********************************************************************************/
public:
    // server: chuẩn bị WSA
    // client: chuẩn bị WSA + client_id ban đầu
    bool InitChannel()
    {
        if (mPort == 0)
        {
            mPort = CPT_DEFAULT_SOCKET_PORT;
        }
        if (!WinSocket::Startup())
        {
            return false;
        }
        if (IsClientMode())
        {
            mId = MakeClientId();
            LOGD("channel port=" + (string)mPort + " client_id=" + (string)mId);
        }
        return true;
    }

    // server: mở cổng lắng nghe (1 lần)
    // client: kết nối server + gửi HELLO
    bool Open()
    {
        if (mPort == 0)
        {
            mPort = CPT_DEFAULT_SOCKET_PORT;
        }
        if (!WinSocket::Startup())
        {
            return false;
        }
        if (IsServerMode())
        {
            return OpenAsServer();
        }
        return OpenAsClient();
    }

    // đóng kết nối / dừng lắng nghe
    // server: terminate khi đóng EA
    // client: terminate khi mất kết nối server hoặc đóng EA
    void Close()
    {
        for (int i = 0; i < mPeerCount; i++)
        {
            if (mPeers[i] != NULL)
            {
                delete mPeers[i];
                mPeers[i] = NULL;
            }
        }
        mPeerCount = 0;

        if (mServer != NULL)
        {
            delete mServer;
            mServer = NULL;
        }

        WinSocket::CloseSock(mListenSock);
        mListening = false;
        WinSocket::Cleanup();
    }

    /**********************************************************************************
    *
    *   send data to the remote terminal
    *
    ***********************************************************************************/
public:
    // server: broadcast cho tất cả client (client tự lọc theo "to_client")
    // client: gửi lên server
    void SendData(string jsonData)
    {
        if (IsServerMode())
        {
            for (int i = 0; i < mPeerCount; i++)
            {
                if (mPeers[i] == NULL)
                {
                    continue;
                }
                if (!WinSocket::SendLine(mPeers[i].mSock, jsonData))
                {
                    mPeers[i].mDead = true;
                }
            }
            return;
        }

        if (mServer == NULL || !mServer.IsOpen())
        {
            LOGE("can not SendData: not connected to server");
            return;
        }
        if (!WinSocket::SendLine(mServer.mSock, jsonData))
        {
            mServer.mDead = true;
        }
    }

    /**********************************************************************************
    *
    *   connection functions - tương ứng CheckInputFile()/GetClientList()
    *
    ***********************************************************************************/
public:
    // server: còn đang lắng nghe không
    // client: còn kết nối với server không
    bool IsAlive()
    {
        if (IsServerMode())
        {
            return mListening;
        }
        return (mServer != NULL && mServer.IsOpen());
    }

    // server: danh sách client đã HELLO
    // client: không dùng
    int GetClientList(int &clientIdList[])
    {
        ArrayResize(clientIdList, 0);
        int count = 0;
        for (int i = 0; i < mPeerCount; i++)
        {
            if (mPeers[i] == NULL || !mPeers[i].mHello)
            {
                continue;
            }
            ArrayResize(clientIdList, count + 1);
            clientIdList[count] = mPeers[i].mId;
            count++;
        }
        return count;
    }

    int GetId()
    {
        return mId;
    }

    /**********************************************************************************
    *
    *   polling - tương ứng SeekToEndInputFile()/PollData()
    *
    ***********************************************************************************/
public:
    // client: chỉ đọc dữ liệu từ lúc kết nối (socket ko có dữ liệu cũ)
    void SkipStaleData()
    {
        if (mServer != NULL)
        {
            mServer.ClearBuffer();
        }
    }

    // server: accept/đọc/dọn kết nối - gọi mỗi tick
    // client: không dùng (đọc nằm trong PollData)
    void Pump()
    {
        if (IsServerMode())
        {
            PumpAsServer();
            return;
        }
        // client: không đọc ở đây - bản tin được đọc trong PollData()
        // (Pump() của client chỉ để server gọi, tránh nuốt mất dữ liệu)
    }

    // client: đọc bản tin JSON từ server
    // server: bản này không xử lý lệnh từ client -> trả về 0
    int PollData(string &cmdList[])
    {
        ArrayResize(cmdList, 0);
        if (IsServerMode())
        {
            PumpAsServer();     // server vẫn phải accept/đọc để giữ kết nối sống
            return 0;
        }
        if (mServer == NULL)
        {
            return 0;
        }
        return mServer.ReadMessages(cmdList);
    }
};

#endif
