//+------------------------------------------------------------------+
//|                                 Lunar-Gaussian Stoch RSI EA      |
//|                                      Converted from Pine Script  |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
CTrade trade;

input bool UseLunarFilter = true; // Enable Lunar Cycle Filter
input int SmoothK = 3; // Stoch RSI K
input int SmoothD = 3; // Stoch RSI D
input int LengthRSI = 14; // RSI Length
input int LengthStoch = 14; // Stochastic Length
input int Poles = 4; // Gaussian Filter Poles
input int SamplingPeriod = 144; // Gaussian Filter Sampling Period
input double Mult = 1.414; // Filtered True Range Multiplier
input double CommissionPercent = 0.1; // Commission Percentage
input double InitialCapital = 100000; // Initial Capital

// Lunar Phase Approximation
double LunarDays = 29.53; // Average lunar cycle length in days
double MoonPhase = 0.0;

// Indicator Handles
int RSIHandle;
int StochHandle;
int ATRHandle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize indicator handles
    RSIHandle = iRSI(_Symbol, _Period, LengthRSI, PRICE_CLOSE);
    StochHandle = iStochastic(_Symbol, _Period, LengthStoch, SmoothK, SmoothD, MODE_SMA, STO_LOWHIGH);
    ATRHandle = iATR(_Symbol, _Period, 14);

    if (RSIHandle == INVALID_HANDLE || StochHandle == INVALID_HANDLE || ATRHandle == INVALID_HANDLE)
    {
        Print("Error initializing indicators");
        return(INIT_FAILED);
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(RSIHandle);
    IndicatorRelease(StochHandle);
    IndicatorRelease(ATRHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for new bar
    static datetime lastBarTime = 0;
    if (lastBarTime == iTime(_Symbol, _Period, 0))
        return;
    lastBarTime = iTime(_Symbol, _Period, 0);

    // Lunar Phase Calculation
    MoonPhase = (TimeCurrent() % (int)(LunarDays * 86400)) / (LunarDays * 86400);
    bool IsNewMoon = UseLunarFilter ? MoonPhase < 0.05 : true;
    bool IsFullMoon = UseLunarFilter ? MoonPhase > 0.45 && MoonPhase < 0.55 : true;

    // Get Indicator Values
    double RSIValue[1];
    double StochK[1], StochD[1];
    double ATRValue[1];

    if (CopyBuffer(RSIHandle, 0, 0, 1, RSIValue) != 1 ||
        CopyBuffer(StochHandle, 0, 0, 1, StochK) != 1 ||
        CopyBuffer(StochHandle, 1, 0, 1, StochD) != 1 ||
        CopyBuffer(ATRHandle, 0, 0, 1, ATRValue) != 1)
    {
        Print("Error copying indicator buffers");
        return;
    }

    // Gaussian Filter Calculation
    double Gaussian = iMA(_Symbol, _Period, Poles, 0, MODE_EMA, PRICE_MEDIAN, 0);
    double HBand = Gaussian + ATRValue[0] * Mult;
    double LBand = Gaussian - ATRValue[0] * Mult;

    // Trading Conditions
    bool IsGreenChannel = Gaussian > Gaussian[1];
    bool IsRedChannel = Gaussian < Gaussian[1];
    bool IsPriceAboveHighBand = iClose(_Symbol, _Period, 0) > HBand;
    bool IsPriceBelowLowBand = iClose(_Symbol, _Period, 0) < LBand;
    bool IsStochRising = StochK[0] > StochD[0];
    bool IsStochFalling = StochK[0] < StochD[0];

    // Long and Short Entry Conditions
    bool LongCondition = IsGreenChannel && IsPriceAboveHighBand && IsStochRising && IsNewMoon;
    bool ShortCondition = IsRedChannel && IsPriceBelowLowBand && IsStochFalling && IsFullMoon;

    // Long and Short Exit Conditions
    bool CloseLongCondition = iClose(_Symbol, _Period, 0) < HBand;
    bool CloseShortCondition = iClose(_Symbol, _Period, 0) > LBand;

    // Execute Trades
    if (LongCondition && PositionSelect(_Symbol) == false)
    {
        trade.Buy(0.1); // Adjust lot size as needed
    }
    if (ShortCondition && PositionSelect(_Symbol) == false)
    {
        trade.Sell(0.1); // Adjust lot size as needed
    }
    if (CloseLongCondition && PositionSelect(_Symbol) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
        trade.PositionClose(_Symbol);
    }
    if (CloseShortCondition && PositionSelect(_Symbol) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
    {
        trade.PositionClose(_Symbol);
    }
}

//+------------------------------------------------------------------+