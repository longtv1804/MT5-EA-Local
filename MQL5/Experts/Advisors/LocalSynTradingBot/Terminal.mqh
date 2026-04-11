#include "Types.mqh"
#include "Constanst.mqh"
#include "Utils.mqh"

class Terminal
{
protected:
    Terminal() {}
    ~Terminal() {}

    //=========================================================
    // func quản lý cho m_OpenPositions
    //=========================================================
    iPosition m_OpenPositions[];
    void UpdateCurrentPositions(iPosition &currPostions[])
    {
        ArrayResize(m_OpenPositions, ArraySize(currPostions));
        for (int i = 0; i < ArraySize(currPostions); i++)
        {
            m_OpenPositions[i] = currPostions[i];
        }
    }
    void AddPosition(iPosition &info)
    {
        int size = ArraySize(m_OpenPositions);
        ArrayResize(m_OpenPositions, size + 1);
        m_OpenPositions[size] = info;
    }
    void RemovePositionByTicket(ulong position_ticket)
    {
        int size = ArraySize(m_OpenPositions);
        for(int i = 0; i < size; i++)
        {
            if(m_OpenPositions[i].position_ticket == position_ticket)
            {
                for(int j = i; j < size - 1; j++)
                {
                    m_OpenPositions[j] = m_OpenPositions[j + 1];
                }
                ArrayResize(m_OpenPositions, size - 1);
                break;
            }
        }
    }
    void UpdatePosition(iPosition &info)
    {
        int size = ArraySize(m_OpenPositions);
        for(int i = 0; i < size; i++)
        {
            if(m_OpenPositions[i].position_ticket == info.position_ticket)
            {
                m_OpenPositions[i] = info;
                break;
            }
        }
    }
    iPosition GetPositionsByTicket(ulong position_ticket)
    {
        int size = ArraySize(m_OpenPositions);
        int idx = 0;
        for(idx = 0; idx < size; idx++)
        {
            if(m_OpenPositions[idx].position_ticket == position_ticket)
            {
                break;
            }
        }
        return m_OpenPositions[idx];
    }
    double GetVolume()
    {
        double sum = 0;
        for (int i = 0; i < ArraySize(m_OpenPositions); i++)
        {
            sum += m_OpenPositions[i].volume;
        }
        return sum;
    }
    // so sánh 2 mảng position để tìm ra position mới mở và position đã đóng.
    void ComparePositions(iPosition &currPostions[], iPosition &newPositions[], iPosition &closedPositions[])
    {
        // check new positions
        int i = 0;
        int j = 0;
        int size = 0;
        for (i = 0; i < ArraySize(currPostions); i++)
        {
            bool isNew = true;
            for (j = 0; j < ArraySize(m_OpenPositions); j++)
            {
                if (currPostions[i].position_ticket == m_OpenPositions[j].position_ticket)
                {
                    isNew = false;
                    break;
                }
            }
            if (isNew)
            {
                size = ArraySize(newPositions);
                ArrayResize(newPositions, size + 1);
                newPositions[size] = currPostions[i];
            }
        }

        // check closed positions
        for (i = 0; i < ArraySize(m_OpenPositions); i++)
        {
            bool isClosed = true;
            for (j = 0; j < ArraySize(currPostions); j++)
            {
                if (m_OpenPositions[i].position_ticket == currPostions[j].position_ticket)
                {
                    isClosed = false;
                    break;
                }
            }
            if (isClosed)
            {
                m_OpenPositions[i].status = ePOSITION_STATUS_CLOSED; // cập nhật trạng thái đóng cho position
                
                size = ArraySize(closedPositions);
                ArrayResize(closedPositions, size + 1);
                closedPositions[size] = m_OpenPositions[i];
            }
        }
    }

protected:
    // data validation:
    //      + postions phải có cùng symbol
    //      + postions phải có cùng type (BUY hoặc SELL)
    static bool CheckPositionsValidation(iPosition &positions[])
    {
        int size = ArraySize(positions);
        bool isValid = true;
        if (size > 0)
        {
            // Tìm tất cả các symbol khác nhau trong positions
            string symbols = positions[0].symbol;
            bool isMultipleSymbols = false;
            bool isSameType = true;
            for (int i = 1; i < size; i++)
            {
                bool hasDifference = false;
                for (int j = 0; j < i; j++)
                {
                    if (positions[i].symbol != positions[j].symbol)
                    {
                        hasDifference = true;
                        break;
                    }
                }
                if (hasDifference == true)
                {
                    symbols += " " + positions[i].symbol;
                    isMultipleSymbols = true;
                }
                if (positions[0].position_type != positions[i].position_type)
                {
                    isSameType = false;
                }
            }

            isValid = !isMultipleSymbols && isSameType;
            if (!isValid)
            {
                LOGE("[DataValidation] " + symbols + ", isSameType=" + (isSameType ? "true" : "false"));
            }
        }
        return isValid;
    }

    //=========================================================
    // virtual func cho Local và Remote terminal override
    //=========================================================
public:
    virtual void init(Terminal* remoteTerminal) = 0;
    virtual void termniate() = 0;
    virtual void ResetTradingSession() = 0;
    virtual double GetAliveVolume() = 0;

    // Remote -> Local: báo cho Local Remote bị disconnected
    virtual void OnRemote_Disconnected()
    {}
    // Remote -> Local: báo cho Local nhận dc CONNECTING từ remote
	virtual void OnRemote_DoConnecting()
	{}
    // Remote -> Local: thông báo đã kết nối với remote.
	virtual void OnRemote_Connected(double remoteClosedVolumeBySLSO, double remoteAliveVolume)
	{}
    // Remote -> Local: gửi thông tin về volume đã bị đóng bởi SL hoặc StopOut từ phía remote
    // và volume còn lại đang mở, để phục vụ cho việc tính toán logic auto TP ở local terminal.
	virtual void OnRemote_Update(double remoteClosedVolumeBySLSO, double remoteAliveVolume)
	{}
    // Remote -> Local: thông báo đã stoploss hoặc stopout bên phía remote.
	virtual void OnRemote_SLSO(double remote_closedVolumeBySLSO, double remote_aliveVolume)
	{}

    //
    // sử dụng ở LocalTerminal.
    //
	virtual void OnLocal_OnTradeTransaction()
	{}
};
