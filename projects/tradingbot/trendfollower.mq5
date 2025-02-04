//+------------------------------------------------------------------+
//|                  Trend Following EA with Trailing Stop             |
//|                 Copyright 2025                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

// External parameters
extern int SlowMA_Period = 50;    // Trend identification MA period
extern int FastMA_Period = 10;    // Entry signal MA period
extern double RiskPips = 5.0;     // Initial stop loss in pips
extern double RewardPips = 10.0;  // Take profit in pips
extern double TrailingStart = 5.0; // Pips of profit before trailing begins
extern double TrailingStep = 1.0;  // Trailing step in pips

// Global variables
double pipSize;
int magicNumber = 12345;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set pip size based on digits
    pipSize = (Digits == 3 || Digits == 5) ? Point * 10 : Point;
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for open positions
    if (OrdersTotal() > 0)
    {
        ManageTrailingStop();
        return;
    }
    
    // Get MA values
    double slowMA = iMA(NULL, 0, SlowMA_Period, 0, MODE_SMA, PRICE_CLOSE, 1);
    double slowMA_prev = iMA(NULL, 0, SlowMA_Period, 0, MODE_SMA, PRICE_CLOSE, 2);
    double fastMA = iMA(NULL, 0, FastMA_Period, 0, MODE_SMA, PRICE_CLOSE, 1);
    double fastMA_prev = iMA(NULL, 0, FastMA_Period, 0, MODE_SMA, PRICE_CLOSE, 2);
    
    // Trading logic
    if (fastMA > slowMA && fastMA_prev <= slowMA_prev)
    {
        // Buy signal
        double stopLoss = Ask - (RiskPips * pipSize);
        double takeProfit = Ask + (RewardPips * pipSize);
        
        int ticket = OrderSend(Symbol(), OP_BUY, 0.1, Ask, 3, stopLoss, takeProfit,
                             "Trend Following EA", magicNumber, 0, clrGreen);
    }
    else if (fastMA < slowMA && fastMA_prev >= slowMA_prev)
    {
        // Sell signal
        double stopLoss = Bid + (RiskPips * pipSize);
        double takeProfit = Bid - (RewardPips * pipSize);
        
        int ticket = OrderSend(Symbol(), OP_SELL, 0.1, Bid, 3, stopLoss, takeProfit,
                             "Trend Following EA", magicNumber, 0, clrRed);
    }
}

//+------------------------------------------------------------------+
//| Manage trailing stop for open positions                           |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != magicNumber) continue;
        
        double currentStop = OrderStopLoss();
        
        if (OrderType() == OP_BUY)
        {
            double newStop = NormalizeDouble(Bid - (TrailingStep * pipSize), Digits);
            if (Bid - OrderOpenPrice() > TrailingStart * pipSize)
            {
                if (currentStop < newStop - pipSize)
                {
                    OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrGreen);
                }
            }
        }
        else if (OrderType() == OP_SELL)
        {
            double newStop = NormalizeDouble(Ask + (TrailingStep * pipSize), Digits);
            if (OrderOpenPrice() - Ask > TrailingStart * pipSize)
            {
                if (currentStop > newStop + pipSize || currentStop == 0)
                {
                    OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrRed);
                }
            }
        }
    }
}