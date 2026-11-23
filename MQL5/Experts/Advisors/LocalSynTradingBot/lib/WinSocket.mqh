//+------------------------------------------------------------------+
//|                                                WinSocket.mqh |
//|  Wrapper gọi Winsock (ws2_32.dll) từ MQL5                        |
//|  Giao tiếp socket TCP nội bộ qua 127.0.0.1                       |
//|                                                                  |
//|  LƯU Ý QUAN TRỌNG:                                               |
//|   - Phải bật cho phép import DLL:                                |
//|       Tools -> Options -> Expert Advisors -> Allow DLL imports   |
//|       (và chọn "Any location" nếu terminal giới hạn DLL          |
//|        ngoài thư mục MQL5\Libraries)                             |
//|   - Dành cho MetaTrader 5 64-bit (mặc định).                      |
//|   - Socket được đặt non-blocking để không làm đơ terminal.       |
//+------------------------------------------------------------------+
#ifndef LOCALSYN_WIN_SOCKET_MQH
#define LOCALSYN_WIN_SOCKET_MQH

#include "../common/Logging.mqh"

//---- hằng số Winsock------------------------------------------------
#define CS_AF_INET              2
#define CS_SOCK_STREAM          1
#define CS_IPPROTO_TCP          6
#define CS_BACKLOG              128

#define CS_FIONBIO              2147772030    // 0x8004667E - set non-blocking
#define CS_SOL_SOCKET           0xFFFF
#define CS_SO_REUSEADDR         4

#define CS_WSAEWOULDBLOCK       10035         // thao tác sẽ block (chưa có dữ liệu)

#define CS_INVALID_SOCKET       ((long)-1)
#define CS_SOCKET_ERROR         (-1)
#define CS_SOCK_ADDR_SIZE       16            // sizeof(struct sockaddr_in)

#define CS_SEND_MAX_IDLE        200           // tối đa 200ms chờ socket sẵn sàng để send

//---- import hàm từ ws2_32.dll --------------------------------------
//  LƯU Ý: sockaddr_in được truyền dưới dạng mảng uchar[16] thuần
//  (MQL5 không có #pragma pack nên dùng buffer để chắc chắn đúng layout)
#import "ws2_32.dll"
    int     WSAStartup(ushort wVersionRequired, uchar &wsaData[]);
    int     WSACleanup();
    int     WSAGetLastError();
    long    socket(int af, int type, int protocol);
    int     closesocket(long s);
    int     ioctlsocket(long s, long cmd, uint &argp);
    int     setsockopt(long s, int level, int optname, const uchar &optval[], int optlen);
    int     bind(long s, const uchar &addr[], int namelen);
    int     listen(long s, int backlog);
    long    accept(long s, uchar &addr[], int &addrlen);
    int     connect(long s, const uchar &addr[], int namelen);
    int     send(long s, const uchar &buf[], int len, int flags);
    int     recv(long s, uchar &buf[], int len, int flags);
#import

//+------------------------------------------------------------------+
//| trạng thái WSA                                                    |
//+------------------------------------------------------------------+
bool g_WinSocketStarted = false;

//+------------------------------------------------------------------+
//| wrapper các thao tác socket                                       |
//+------------------------------------------------------------------+
class WinSocket
{
private:
    //------------------------------------------------------------------
    // non-blocking cho 1 socket
    //------------------------------------------------------------------
    static bool SetNonBlocking(const long s)
    {
        uint nonBlock = 1;
        if (ioctlsocket(s, CS_FIONBIO, nonBlock) != 0)
        {
            LOGE("ioctlsocket(FIONBIO) failed, err=" + (string)WSAGetLastError());
            return false;
        }
        return true;
    }

    //------------------------------------------------------------------
    // địa chỉ 127.0.0.1:port - đóng gói đúng 16 byte của sockaddr_in:
    //   [0..1] sin_family = AF_INET (2, little endian)
    //   [2..3] sin_port    = htons(port)
    //   [4..7] sin_addr    = 127.0.0.1
    //   [8..15] sin_zero   = 0
    //------------------------------------------------------------------
    static void FillLocalAddr(uchar &addr[], const ushort port)
    {
        addr[0] = (uchar)(CS_AF_INET & 0xFF);
        addr[1] = 0;
        addr[2] = (uchar)((port >> 8) & 0xFF);      // htons
        addr[3] = (uchar)(port & 0xFF);
        addr[4] = 127;
        addr[5] = 0;
        addr[6] = 0;
        addr[7] = 1;
        for (int i = 8; i < CS_SOCK_ADDR_SIZE; i++)
        {
            addr[i] = 0;
        }
    }

public:
    //------------------------------------------------------------------
    // khởi tạo WSA (idempotent)
    //------------------------------------------------------------------
    static bool Startup()
    {
        if (g_WinSocketStarted)
        {
            return true;
        }
        uchar wsaData[512];
        int res = WSAStartup(0x0202, wsaData);
        if (res != 0)
        {
            LOGE("WSAStartup failed, res=" + (string)res);
            return false;
        }
        g_WinSocketStarted = true;
        LOGD("Winsock started");
        return true;
    }

    static void Cleanup()
    {
        if (g_WinSocketStarted)
        {
            WSACleanup();
            g_WinSocketStarted = false;
            LOGD("Winsock cleaned up");
        }
    }

    //------------------------------------------------------------------
    // tạo socket TCP non-blocking
    //------------------------------------------------------------------
    static long CreateStream()
    {
        if (!Startup())
        {
            return CS_INVALID_SOCKET;
        }
        long s = socket(CS_AF_INET, CS_SOCK_STREAM, CS_IPPROTO_TCP);
        if (s == CS_INVALID_SOCKET)
        {
            LOGE("socket() failed, err=" + (string)WSAGetLastError());
            return CS_INVALID_SOCKET;
        }
        if (!SetNonBlocking(s))
        {
            closesocket(s);
            return CS_INVALID_SOCKET;
        }
        return s;
    }

    //------------------------------------------------------------------
    // SERVER: mở cổng lắng nghe trên 127.0.0.1:port
    //------------------------------------------------------------------
    static bool Listen(const ushort port, long &sock)
    {
        long s = CreateStream();
        if (s == CS_INVALID_SOCKET)
        {
            return false;
        }

        // cho phép bind lại cổng ngay khi còn socket ở trạng thái TIME_WAIT
        // (phát hiện "server đã tồn tại" được thực hiện riêng bằng ConnectProbe)
        uchar reuse[4];
        reuse[0] = 1;
        reuse[1] = 0;
        reuse[2] = 0;
        reuse[3] = 0;
        setsockopt(s, CS_SOL_SOCKET, CS_SO_REUSEADDR, reuse, 4);

        uchar addr[CS_SOCK_ADDR_SIZE];
        FillLocalAddr(addr, port);
        if (bind(s, addr, CS_SOCK_ADDR_SIZE) != 0)
        {
            int err = WSAGetLastError();
            LOGE("bind(" + (string)port + ") failed, err=" + (string)err);
            closesocket(s);
            return false;
        }
        if (listen(s, CS_BACKLOG) != 0)
        {
            LOGE("listen(" + (string)port + ") failed, err=" + (string)WSAGetLastError());
            closesocket(s);
            return false;
        }
        sock = s;
        LOGD("listening on 127.0.0.1:" + (string)port);
        return true;
    }

    //------------------------------------------------------------------
    // CLIENT: kết nối tới 127.0.0.1:port
    //   - kết nối thành công: trả về socket (đã non-blocking)
    //   - server chưa chạy:   trả về CS_INVALID_SOCKET (localhost: fail ngay)
    //------------------------------------------------------------------
    static long ConnectTo(const ushort port)
    {
        if (!Startup())
        {
            return CS_INVALID_SOCKET;
        }
        long s = socket(CS_AF_INET, CS_SOCK_STREAM, CS_IPPROTO_TCP);   // blocking
        if (s == CS_INVALID_SOCKET)
        {
            LOGE("socket() failed, err=" + (string)WSAGetLastError());
            return CS_INVALID_SOCKET;
        }

        uchar addr[CS_SOCK_ADDR_SIZE];
        FillLocalAddr(addr, port);
        if (connect(s, addr, CS_SOCK_ADDR_SIZE) != 0)
        {
            closesocket(s);
            return CS_INVALID_SOCKET;    // WSAECONNREFUSED: chưa có server
        }

        SetNonBlocking(s);
        return s;
    }

    //------------------------------------------------------------------
    // SERVER: accept 1 kết nối tới
    //   - không có kết nối nào chờ: trả về CS_INVALID_SOCKET
    //------------------------------------------------------------------
    static long AcceptNew(const long listenSock)
    {
        uchar addr[CS_SOCK_ADDR_SIZE];
        int addrLen = CS_SOCK_ADDR_SIZE;
        long s = accept(listenSock, addr, addrLen);
        if (s == CS_INVALID_SOCKET)
        {
            return CS_INVALID_SOCKET;
        }
        if (!SetNonBlocking(s))
        {
            closesocket(s);
            return CS_INVALID_SOCKET;
        }
        return s;
    }

    //------------------------------------------------------------------
    // đọc dữ liệu
    //   return > 0 : số byte đọc được
    //   return = 0 : chưa có dữ liệu (would block)
    //   return < 0 : bên kia đóng kết nối / lỗi
    //------------------------------------------------------------------
    static int RecvData(const long s, uchar &buf[], const int size)
    {
        int n = recv(s, buf, size, 0);
        if (n > 0)
        {
            return n;
        }
        if (n == 0)
        {
            return -1;                      // graceful close
        }
        if (WSAGetLastError() == CS_WSAEWOULDBLOCK)
        {
            return 0;
        }
        return -1;
    }

    //------------------------------------------------------------------
    // gửi 1 dòng (tự thêm '\n' làm ranh giới giữa các bản tin)
    //------------------------------------------------------------------
    static bool SendLine(const long s, const string text)
    {
        uchar data[];
        int count = StringToCharArray(text + "\n", data, 0, WHOLE_ARRAY, CP_UTF8);
        int remain = count - 1;             // bỏ ký tự '\0' cuối
        if (remain <= 0)
        {
            return true;
        }

        int idleCount = 0;
        while (remain > 0)
        {
            int sent = send(s, data, remain, 0);
            if (sent > 0)
            {
                // gửi được 1 phần -> đưa phần còn lại về đầu buffer
                if (sent < remain)
                {
                    for (int i = 0; i < remain - sent; i++)
                    {
                        data[i] = data[sent + i];
                    }
                }
                remain -= sent;
                idleCount = 0;
                continue;
            }

            if (sent == CS_SOCKET_ERROR && WSAGetLastError() == CS_WSAEWOULDBLOCK)
            {
                if (++idleCount > CS_SEND_MAX_IDLE)
                {
                    LOGE("send timeout after " + (string)CS_SEND_MAX_IDLE + "ms");
                    return false;
                }
                Sleep(1);
                continue;
            }

            LOGE("send failed, err=" + (string)WSAGetLastError());
            return false;
        }
        return true;
    }

    //------------------------------------------------------------------
    // đóng socket
    //------------------------------------------------------------------
    static void CloseSock(long &s)
    {
        if (s != CS_INVALID_SOCKET)
        {
            closesocket(s);
            s = CS_INVALID_SOCKET;
        }
    }
};

#endif
