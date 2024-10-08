//+------------------------------------------------------------------+
//|                                                 SMAvsEMA_Bot.mq5 |
//|                                         F&F Trading Applications |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "F&F Trading Applications"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>;
CTrade trade;

//--- input parameters
input int      LOTAJE=1;
input int      MAPeriod=5;
input int      TRENDPeriod=200;
input int      TRENDStdDev=1;
input int      ADXPeriod=5;
input int      ATRPeriod=14;

// Variables
   datetime previous_candle_open_time = 0;
   double slPoints = 0;

// Flags
   int trend = 0; // 1 UPTREND; 0 NULL; -1 DOWNTREND

// Handlers
   int handlerEMA;
   int handlerSMA;
   int handlerBB;
   int handlerADX;
   int handlerATR;

// Buffers
   double ema[];
   double sma[];
   double bb_up[];
   double bb_down[];
   double atr[];
   
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   ArraySetAsSeries(ema, true);
   ArraySetAsSeries(sma, true);
   ArraySetAsSeries(bb_up, true);
   ArraySetAsSeries(bb_down, true);
   ArraySetAsSeries(atr, true);
   
   handlerSMA = iMA(_Symbol, _Period,MAPeriod,0,MODE_SMA,PRICE_TYPICAL);
   handlerEMA = iMA(_Symbol, _Period,MAPeriod,0,MODE_EMA,PRICE_TYPICAL);
   handlerBB = iBands(_Symbol,_Period,TRENDPeriod,0,TRENDStdDev,PRICE_TYPICAL);
   handlerATR = iATR(_Symbol,_Period,ATRPeriod);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   ArrayResize(sma,10);
   ArrayResize(ema,10);
   ArrayResize(bb_up,10);
   ArrayResize(bb_down,10);
   ArrayResize(atr,10);
   
   CopyBuffer(handlerSMA,0,0,10,sma);
   CopyBuffer(handlerEMA,0,0,10,ema);
   CopyBuffer(handlerBB,1,0,10,bb_up);
   CopyBuffer(handlerBB,2,0,10,bb_down);
   CopyBuffer(handlerATR,0,0,10,atr);
   
   double high = iHigh(_Symbol,_Period,1);
   double low = iLow(_Symbol,_Period,1);
   double close = iClose(_Symbol,_Period,1);
   
   bool active_order = PositionSelect(_Symbol);
   
   // Comprovamos la dirección de la tendencia
   if (sma[1] > bb_up[1]) {
      trend = 1;
   } else {
      if (sma[1] < bb_down[1]) {
         trend = -1;
      } else {
         trend = 0;
      }
   }
   
   if (active_order == false && isSameBar() == false ) {
      
         // ENTORNO ALCISTA
         if (close > bb_up[1] && low < bb_up[1] && ema[1] > sma[1]) {
            slPoints = NormalizeDouble(atr[1],Digits());
            trade.Buy(LOTAJE,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_ASK),slPoints,NULL,"BUY trade");
         }
   
         // ENTORNO BAJISTA
         if (close < bb_down[1] && high > bb_down[1] && ema[1] < sma[1]) {
            slPoints = NormalizeDouble(atr[1],Digits());
            trade.Sell(LOTAJE,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_BID),slPoints,NULL,"BUY trade");
         }
      
   } else {
   TrailingStop(slPoints);
   /*
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         if (ema[2] > sma[2] && ema[1] < sma[1]) {
            trade.PositionClose(_Symbol);
         }
      } else {
         if (ema[2] < sma[2] && ema[1] > sma[1]) {
            trade.PositionClose(_Symbol);
         }
      }
      
      if (isSameBar() == false) {
      trade.PositionClose(_Symbol);
     }
     */
     
   }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if is the same bar                                         |
//+------------------------------------------------------------------+
bool isSameBar()
  {
// Obtener la hora de apertura de la vela actual
   datetime current_candle_open_time = iTime(_Symbol, PERIOD_CURRENT, 0);

// Comparar la hora de apertura de la vela actual con la de la iteración anterior
   if(current_candle_open_time == previous_candle_open_time)
     {
      return true;
     }
   else
     {
      // Actualizar la variable global con la hora de apertura de la vela actual
      previous_candle_open_time = current_candle_open_time;
      return false;
     }
  }
  
bool tradingHours(int start_hour, int final_hour) {
   MqlDateTime now;
   TimeCurrent(now);
   
   if ( now.hour >= start_hour && final_hour <= now.hour ) {
      
      return true;
      
   }
   return false;
}
  
double NormalizePrice(double price)
  {
   double m_tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return(NormalizeDouble(MathRound(price/m_tick_size)*m_tick_size,_Digits));
  }
  
//+------------------------------------------------------------------+
//| Update trailing stop                                             |
//+------------------------------------------------------------------+
void TrailingStop(int stoploss)
  {
// Check all open positions
   for(int i = 0; i < PositionsTotal(); i++)
     {
      // Get the position ticket
      ulong ticket = PositionGetTicket(i);
      // Get the position details
      if(PositionSelectByTicket(ticket))
        {
         double stopLoss = PositionGetDouble(POSITION_SL);
         double takeProfit = PositionGetDouble(POSITION_TP);
         double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double trailingStop = 0;

         // Check if the position is a buy or sell
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            // Calculate the trailing stop for a buy position
            trailingStop = NormalizeDouble((currentPrice - stoploss), Digits());
            // Update the stop loss if the new trailing stop is higher than the current stop loss
            if(stopLoss < trailingStop && trailingStop < currentPrice)
              {
               bool flag_1 = trade.PositionModify(ticket, trailingStop, takeProfit);
               // Modify the position with the new stop loss
               if(flag_1 == false)
                 {
                  Print("Error modifying position: ", GetLastError());
                 }
              }
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               // Calculate the trailing stop for a sell position
               trailingStop = NormalizeDouble((currentPrice + stoploss), Digits());
               // Update the stop loss if the new trailing stop is lower than the current stop loss
               if(stopLoss > trailingStop && trailingStop > currentPrice)
                 {
                  // Modify position with the new stop loss
                  bool flag_2 = trade.PositionModify(ticket, trailingStop, takeProfit);
                  if(flag_2 == false)
                    {
                     Print("Error modifying position: ", GetLastError());
                    }
                 }
              }
        }
     }
  }
//+------------------------------------------------------------------+