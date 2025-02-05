//+------------------------------------------------------------------+
//|                  Trend Following EA with Trailing Stop MT5         |
//|                 Copyright 2025                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict

// Include required MT5 trade functions
#include <Trade\Trade.mqh>

// Input parameters
input int    SlowMA_Period = 50;    // Trend identification MA period
input int    FastMA_Period = 10;    // Entry signal MA period
input double RiskPips     = 5.0;    // Initial stop loss in pips
input double RewardPips   = 10.0;   // Take profit in pips
input double TrailingStart = 5.0;   // Pips of profit before trailing begins
input double TrailingStep  = 1.0;   // Trailing step in pips
input double LotSize      = 0.1;    // Trading lot size

// Global variables
CTrade trade;  // Trading object
double g_point;
int    g_magic = 12345;
int    g_slowMA_handle;
int    g_fastMA_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize point value
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(_Digits == 3 || _Digits == 5)
      g_point *= 10;
      
   // Set magic number for trade identification
   trade.SetExpertMagicNumber(g_magic);
   
   // Initialize MA handles
   g_slowMA_handle = iMA(_Symbol, PERIOD_CURRENT, SlowMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   g_fastMA_handle = iMA(_Symbol, PERIOD_CURRENT, FastMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   
   if(g_slowMA_handle == INVALID_HANDLE || g_fastMA_handle == INVALID_HANDLE)
   {
      Print("Error creating MA indicators");
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(g_slowMA_handle);
   IndicatorRelease(g_fastMA_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for open positions
   if(PositionsTotal() > 0)
   {
      ManageTrailingStop();
      return;
   }
   
   // Arrays for MA values
   double slowMA[], fastMA[];
   ArraySetAsSeries(slowMA, true);
   ArraySetAsSeries(fastMA, true);
   
   // Copy MA values
   if(CopyBuffer(g_slowMA_handle, 0, 0, 3, slowMA) <= 0) return;
   if(CopyBuffer(g_fastMA_handle, 0, 0, 3, fastMA) <= 0) return;
   
   // Get current prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Trading logic
   if(fastMA[1] > slowMA[1] && fastMA[2] <= slowMA[2])
   {
      double stopLoss = NormalizeDouble(ask - (RiskPips * g_point), _Digits);
      double takeProfit = NormalizeDouble(ask + (RewardPips * g_point), _Digits);
      
      trade.Buy(LotSize, _Symbol, ask, stopLoss, takeProfit, "Trend Following EA");
   }
   else if(fastMA[1] < slowMA[1] && fastMA[2] >= slowMA[2])
   {
      double stopLoss = NormalizeDouble(bid + (RiskPips * g_point), _Digits);
      double takeProfit = NormalizeDouble(bid - (RewardPips * g_point), _Digits);
      
      trade.Sell(LotSize, _Symbol, bid, stopLoss, takeProfit, "Trend Following EA");
   }
}

//+------------------------------------------------------------------+
//| Manage trailing stop for open positions                           |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(!PositionSelectByTicket(ticket)) continue;
      
      // Check if position belongs to this EA
      if(PositionGetInteger(POSITION_MAGIC) != g_magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      double currentStop = PositionGetDouble(POSITION_SL);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      if(posType == POSITION_TYPE_BUY)
      {
         if(currentPrice - openPrice > TrailingStart * g_point)
         {
            double newStop = NormalizeDouble(currentPrice - (TrailingStep * g_point), _Digits);
            if(currentStop < newStop - g_point)
            {
               trade.PositionModify(ticket, newStop, PositionGetDouble(POSITION_TP));
            }
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         if(openPrice - currentPrice > TrailingStart * g_point)
         {
            double newStop = NormalizeDouble(currentPrice + (TrailingStep * g_point), _Digits);
            if(currentStop > newStop + g_point || currentStop == 0)
            {
               trade.PositionModify(ticket, newStop, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}