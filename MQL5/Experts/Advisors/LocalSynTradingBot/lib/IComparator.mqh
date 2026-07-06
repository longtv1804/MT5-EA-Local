#include "../common/Types.mqh"

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

