#include "../common/Types.mqh"
#include "../queue/Event.mqh"

template<typename T>
class IComparator
{
public:
   virtual bool Equals(const T &a, const T &b) = 0;
};

class IntComparator : public IComparator<int>
{
public:
   bool Equals(const int &a, const int &b)
   {
      return a == b;
   }
};

class UlongComparator : public IComparator<ulong>
{
public:
   bool Equals(const ulong &a, const ulong &b)
   {
      return a == b;
   }
};

class DoubleComparator : public IComparator<double>
{
public:
   bool Equals(const double &a, const double &b)
   {
      return MathAbs(a - b) < 0.001;
   }
};

class iPositionComparator : public IComparator<iPosition>
{
public:
   bool Equals(const iPosition &a, const iPosition &b)
   {
      return a.position_ticket == b.position_ticket;
   }
};

class EventComparator : public IComparator<Event>
{
private:
   int mBitMark;
public:
   enum
   {
      CHECK_BIT_MARK_eventId        = 1 << 0,
      CHECK_BIT_MARK_handler     	= 1 << 1,
      CHECK_BIT_MARK_arg_int_1   	= 1 << 2,
      CHECK_BIT_MARK_arg_int_2    	= 1 << 3,
      CHECK_BIT_MARK_arg_ulong_1    = 1 << 4,
      CHECK_BIT_MARK_arg_ulong_2    = 1 << 5,
      CHECK_BIT_MARK_arg_double_1   = 1 << 6,
      CHECK_BIT_MARK_arg_double_2   = 1 << 7,
      CHECK_BIT_MARK_arg_string     = 1 << 8,
      CHECK_BIT_MARK_data           = 1 << 9,
   };

   EventComparator()
   {
      mBitMark = 0;
      mBitMark |= CHECK_BIT_MARK_eventId;
      mBitMark |= CHECK_BIT_MARK_handler;
   }

   void SetBitMark(int bitmark)
   {
      mBitMark |= bitmark;
   }

   bool Equals(const Event &a, const Event &b)
   {
      if ((mBitMark & CHECK_BIT_MARK_eventId)      != 0 && (a.eventId != b.eventId)                         ) return false;
      if ((mBitMark & CHECK_BIT_MARK_handler)      != 0 && (a.handler != b.handler)                         ) return false;
      if ((mBitMark & CHECK_BIT_MARK_arg_int_1)    != 0 && (a.arg_int_1 != b.arg_int_1)                     ) return false;
      if ((mBitMark & CHECK_BIT_MARK_arg_int_2)    != 0 && (a.arg_int_2 != b.arg_int_2)                     ) return false;
      if ((mBitMark & CHECK_BIT_MARK_arg_double_1) != 0 && MathAbs(a.arg_double_1 - b.arg_double_1) > 0.001 ) return false;
      if ((mBitMark & CHECK_BIT_MARK_arg_double_2) != 0 && MathAbs(a.arg_double_2 - b.arg_double_2) > 0.001 ) return false;
      if ((mBitMark & CHECK_BIT_MARK_arg_ulong_1)  != 0 && (a.arg_ulong_1 != b.arg_ulong_1)                 ) return false;
      if ((mBitMark & CHECK_BIT_MARK_arg_ulong_2)  != 0 && (a.arg_ulong_2 != b.arg_ulong_2)                 ) return false;
      if ((mBitMark & CHECK_BIT_MARK_arg_string)   != 0 && (a.arg_string != b.arg_string)                   ) return false;
      if ((mBitMark & CHECK_BIT_MARK_data)         != 0)
      {
         if (ArraySize(a.data) != ArraySize(b.data)) return false;
         int dataSize = ArraySize(a.data);
         for (int i = 0; i < dataSize; i++)
         {
            if (a.data[i] != b.data[i]) return false;
         }
      }
      return true;
   }
};