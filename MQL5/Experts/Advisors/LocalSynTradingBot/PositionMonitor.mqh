#include "/common/Types.mqh"
#include "/common/Utils.mqh"
#include "/common/TerminalApi.mqh"
#include "/common/Logging.mqh"
#include "/copytrade/InstanceHolder.mqh"
#include "/copytrade/CPT_LocalTerminal.mqh"

class PositionMonitor
{
private:
    iPosition mPositions[];

    static PositionMonitor mInstance;
    PositionMonitor()
    {}

    static int FindPositionIndex(iPosition &arr[], ulong ticket)
    {
        int total = ArraySize(arr);
        for(int i = 0; i < total; i++)
        {
            if(arr[i].position_ticket == ticket)
                return i;
        }
        return -1;
    }

    void OnNewPositionAdded(const iPosition &pos)
    {
        LOGD("+ POSITION: " + ToString(pos));
        InstanceHolder::GetLocalTerminal().OnPositionAdded(pos);
    }

    void OnPositionClosed(const iPosition &pos)
    {
        LOGD("- POSITION: " + ToString(pos));
        InstanceHolder::GetLocalTerminal().OnPositionClosed(pos);
    }

    void OnPartialPositionClosed(const iPosition &pos)
    {
        LOGD("- Partial-POSITION: " + ToString(pos));

    }

public:
    static PositionMonitor* GetInstance()
    {
        return &mInstance;
    }

    // khi khởi tạo lần đầu cần lấy snapshot để tránh nhận nhầm tất cả các position
    // hiện hữu là new position
    void InitFirstSnapshot()
    {
        // lấy snapshot hiện tại
        iPosition current_positions[];
        TerminalAPI::DoGetAllPosition(current_positions);
        int cur_total  = ArraySize(current_positions);

        // lưu snapshot
        ArrayResize(mPositions, cur_total);
        LOGD("save first snapshot: " + (string)cur_total);
        for(int i = 0; i < cur_total; i++)
        {
            mPositions[i] = current_positions[i];
            LOGD(ToString(mPositions[i]));
        }
    }

    void CheckLocalPositionChanged()
    {
        // lấy snapshot hiện tại
        iPosition current_positions[];
        bool res = false;
        int retryCount = 0;
        while (res == false && retryCount < 3)
        {
            res = TerminalAPI::DoGetAllPosition(current_positions);
            retryCount += 1;
        }
        if (res == false)
        {
            LOGE("can not DoGetAllPosition() after 3 try!!!");
            return;
        }

        int cur_total  = ArraySize(current_positions);
        int prev_total = ArraySize(mPositions);

        int i = 0, idx = 0;
        ulong ticket = 0;

        //==================================================
        // Detect CLOSED positions
        //==================================================
        iPosition closedPos;
        for(i = 0; i < prev_total; i++)
        {
            ticket = mPositions[i].position_ticket;
            idx = FindPositionIndex(current_positions, ticket);
            if(idx < 0)
            {
                closedPos = mPositions[i];
                closedPos.status = ePOSITION_STATUS_CLOSED;
                OnPositionClosed(closedPos);
            }
            else
            {
                if (current_positions[idx].volume < mPositions[i].volume)
                {
                    closedPos = mPositions[i];
                    closedPos.volume = mPositions[i].volume - current_positions[idx].volume;
                    closedPos.status = ePOSITION_STATUS_CLOSED;
                    OnPartialPositionClosed(closedPos);
                }
            }
        }

        //==================================================
        // Detect NEW positions
        //==================================================
        for(i = 0; i < cur_total; i++)
        {
            ticket = current_positions[i].position_ticket;
            idx = FindPositionIndex(mPositions, ticket);
            if(idx < 0)
            {
                OnNewPositionAdded(current_positions[i]);
            }
        }

        //==================================================
        // update snapshot
        //==================================================
        ArrayResize(mPositions, cur_total);
        for(i = 0; i < cur_total; i++)
        {
            mPositions[i] = current_positions[i];
        }
    }
};

PositionMonitor PositionMonitor::mInstance;