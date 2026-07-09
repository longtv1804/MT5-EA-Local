#include "../lib/List.mqh"
#include "Types.mqh"

class TradeUtils
{
public:
    static bool IsSamePrice(double p1, double p2)
    {
        return MathAbs(p1 - p2) < 0.25;
    }

    static double NormalizeVolume(const string symbol, double volume)
    {
        double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double step   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

        volume = MathMax(minLot, MathMin(maxLot, volume));
        volume = MathRound(volume / step) * step;
        int digits = (int)MathRound(-MathLog10(step));

        return NormalizeDouble(volume, digits);
    }

    static double TotalVolume(const List<iPosition> &positions)
    {
        double totalVolume = 0.0;

        for(int i = 0; i < positions.Size(); i++)
        {
            totalVolume += positions.At(i).volume;
        }

        return totalVolume;
    }

    static double AverageOpenPrice(const List<iPosition> &positions)
    {
        double weightedPrice = 0.0;
        double totalVolume   = 0.0;

        for(int i = 0; i < positions.Size(); i++)
        {
            const iPosition *pos = positions.At(i);

            weightedPrice += pos.price_open * pos.volume;
            totalVolume   += pos.volume;
        }

        if(totalVolume <= 0)
            return 0;

        return weightedPrice / totalVolume;
    }

    static double BreakEvenPrice(const List<iPosition> &positions)
    {
        double numerator   = 0.0;
        double denominator = 0.0;

        for(int i = 0; i < positions.Size(); i++)
        {
            const iPosition *pos = positions.At(i);

            double sign = pos.position_type == ePOSITION_TYPE_BUY ? 1.0 : -1.0;

            numerator   += sign * pos.volume * pos.price_open;
            denominator += sign * pos.volume;
        }

        if(MathAbs(denominator) < 0.001)
            return 0.0;

        return numerator / denominator;
    }
};