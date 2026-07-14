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
public:
   bool Equals(const Event &a, const Event &b)
   {
      bool res = false;
      res &= (a.eventId == b.eventId);
      res &= (a.arg1 == b.arg1);
      res &= (a.arg2 == b.arg2);
      res &= (a.arg3 == b.arg3);
      res &= (a.arg4 == b.arg4);
      res &= (a.arg5 == b.arg5);
      res &= (a.arg6 == b.arg6);
      res &= (a.arg7 == b.arg7);
      res &= (a.handler == b.handler);
      res &= (ArraySize(a.data) == ArraySize(b.data));
      if (res)
      {
         int dataSize = ArraySize(a.data);
         for (int i = 0; i < dataSize; i++)
         {
            res &= (a.data[i] == b.data[i]);
         }
      }
      return res;
   }
};