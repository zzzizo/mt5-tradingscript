
#property strict
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

// === TRADING PARAMETERS ===
input string TradeSymbol = "EURUSD";
input double RiskPerTrade = 2.0;        // Risk per trade in % of balance
input int Slippage = 100;
input int MagicNumber = 123456;
input int MaxLongPositions = 5;
input int MaxShortPositions = 5;

// === RISK MANAGEMENT ===
input double MaxDailyLoss = 10.0;       // Max daily loss in % of balance
input double MaxDrawdown = 20.0;        // Max total drawdown in % of balance
input bool UseATRPositionSizing = true; // Use ATR for position sizing
input double ATRMultiplier = 2.0;       // ATR multiplier for stop loss

// === ENTRY FILTERS ===
input bool UseTrendFilter = true;       // Only trade with trend
input bool UseVolumeFilter = true;      // Require volume confirmation   
input double MinVolatility = 0.5;       // Minimum ATR % for trading
input double MaxVolatility = 5.0;       // Maximum ATR % for trading

// === TRAILING STOPS ===
input double BreakevenProfitPct = 1.5;  // Move SL to breakeven at this profit %
input double TrailingStartPct = 3.0;    // Start trailing at this profit %
input double TrailingStepATR = 1.5;     // Trailing distance in ATR multiples

// === TIME FILTERS ===
input bool UseTimeFilter = true;        // Enable time-based filtering
input int TradingStartHour = 8;         // Start trading hour (broker time)
input int TradingEndHour = 22;          // End trading hour (broker time)

// === PARTIAL PROFIT TAKING ===
input bool UsePartialProfits = true;    // Enable partial profit taking
input double PartialProfit1Pct = 2.0;   // First partial profit level %
input double PartialProfit2Pct = 4.0;   // Second partial profit level %
input double PartialSize1 = 30.0;       // % of position to close at level 1
input double PartialSize2 = 30.0;       // % of position to close at level 2

datetime lastTradeDay = 0;
double dailyStartBalance = 0;
double totalStartBalance = 0;

int LongTradesToday = 0;
int ShortTradesToday = 0;

// Indicator handles
int rsiHandle = INVALID_HANDLE;
int macdHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
int ema20Handle = INVALID_HANDLE;
int ema50Handle = INVALID_HANDLE;
int ema200Handle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
int volumeHandle = INVALID_HANDLE;

// Higher timeframe handles for multi-timeframe analysis
int rsiH4Handle = INVALID_HANDLE;
int emaH4_20Handle = INVALID_HANDLE;
int emaH4_50Handle = INVALID_HANDLE;

// Partial profit trackin
struct PartialProfitData {
   ulong ticket;
   bool level1Taken;
   bool level2Taken;
   double originalVolume;
};
PartialProfitData partialProfits[];

// Arrays für Positionstracking

ulong positionTickets[];

double highestPriceLongMap[];

double lowestPriceShortMap[];

//+------------------------------------------------------------------+

//| Initialisierung |

//+------------------------------------------------------------------+

int OnInit()
{
   // Initialize M1 indicators
   rsiHandle = iRSI(TradeSymbol, PERIOD_M1, 14, PRICE_CLOSE);
   macdHandle = iMACD(TradeSymbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE);
   atrHandle = iATR(TradeSymbol, PERIOD_M1, 14);
   ema20Handle = iMA(TradeSymbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
   ema50Handle = iMA(TradeSymbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200Handle = iMA(TradeSymbol, PERIOD_M1, 200, 0, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(TradeSymbol, PERIOD_M1, 14);
   
   // Initialize H4 indicators for multi-timeframe analysis
   rsiH4Handle = iRSI(TradeSymbol, PERIOD_H4, 14, PRICE_CLOSE);
   emaH4_20Handle = iMA(TradeSymbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
   emaH4_50Handle = iMA(TradeSymbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   // Check if all handles are valid
   if(rsiHandle == INVALID_HANDLE || macdHandle == INVALID_HANDLE || 
      atrHandle == INVALID_HANDLE || ema20Handle == INVALID_HANDLE ||
      ema50Handle == INVALID_HANDLE || ema200Handle == INVALID_HANDLE ||
      adxHandle == INVALID_HANDLE || rsiH4Handle == INVALID_HANDLE ||
      emaH4_20Handle == INVALID_HANDLE || emaH4_50Handle == INVALID_HANDLE)
   {
      Print("❌ Fehler beim Erstellen der Indikatorenhandles");
      return(INIT_FAILED);
   }
   
   // Initialize balance tracking
   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   totalStartBalance = dailyStartBalance;
   
   Print("✅ Alle Indikatorenhandles erfolgreich erstellt");
   Print("✅ Startbalance: ", totalStartBalance);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+

void OnDeinit(const int reason)
{
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(macdHandle != INVALID_HANDLE) IndicatorRelease(macdHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(ema20Handle != INVALID_HANDLE) IndicatorRelease(ema20Handle);
   if(ema50Handle != INVALID_HANDLE) IndicatorRelease(ema50Handle);
   if(ema200Handle != INVALID_HANDLE) IndicatorRelease(ema200Handle);
   if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);
   if(rsiH4Handle != INVALID_HANDLE) IndicatorRelease(rsiH4Handle);
   if(emaH4_20Handle != INVALID_HANDLE) IndicatorRelease(emaH4_20Handle);
   if(emaH4_50Handle != INVALID_HANDLE) IndicatorRelease(emaH4_50Handle);
}

//+------------------------------------------------------------------+

//| Hilfsfunktionen für Positionstracking |

//+------------------------------------------------------------------+

int FindPositionIndex(ulong ticket)

{

for(int i=0; i<ArraySize(positionTickets); i++)

if(positionTickets[i] == ticket)

     return i;

return -1;

}

void UpdateHighLowForPosition(ulong ticket, ENUM_POSITION_TYPE type, double price)

{

int idx = FindPositionIndex(ticket);

if(idx == -1) // neu anlegen

{

ArrayResize(positionTickets, ArraySize(positionTickets)+1);

  ArrayResize(highestPriceLongMap, ArraySize(positionTickets));

  ArrayResize(lowestPriceShortMap, ArraySize(positionTickets));

  idx = ArraySize(positionTickets)-1;

  positionTickets[idx] = ticket;

  highestPriceLongMap[idx] = price;

  lowestPriceShortMap[idx] = price;

}

else

{

if(type == POSITION_TYPE_BUY && price > highestPriceLongMap[idx])

     highestPriceLongMap[idx] = price;

  if(type == POSITION_TYPE_SELL && price < lowestPriceShortMap[idx])

     lowestPriceShortMap[idx] = price;

}

}

double GetHighForPosition(ulong ticket)

{

int idx = FindPositionIndex(ticket);

if(idx != -1) return highestPriceLongMap[idx];

return 0;

}

double GetLowForPosition(ulong ticket)

{

int idx = FindPositionIndex(ticket);

if(idx != -1) return lowestPriceShortMap[idx];

return DBL_MAX;

}

void RemovePositionFromTracking(ulong ticket)

{

int idx = FindPositionIndex(ticket);

if(idx == -1) return;

for(int i=idx; i<ArraySize(positionTickets)-1; i++)

{

positionTickets[i] = positionTickets[i+1];

  highestPriceLongMap[i] = highestPriceLongMap[i+1];

  lowestPriceShortMap[i] = lowestPriceShortMap[i+1];

}

ArrayResize(positionTickets, ArraySize(positionTickets)-1);

ArrayResize(highestPriceLongMap, ArraySize(highestPriceLongMap)-1);

ArrayResize(lowestPriceShortMap, ArraySize(lowestPriceShortMap)-1);

}

//+------------------------------------------------------------------+

//| Entfernt getrackte Positionen, die geschlossen wurden |

//+------------------------------------------------------------------+

void CleanupClosedPositions()
{
   // Clean up position tracking arrays
   for(int i = ArraySize(positionTickets) - 1; i >= 0; i--)
   {
      ulong ticket = positionTickets[i];
      bool offen = false;
      
      for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
      {
         ulong posTicket = PositionGetTicket(pos);
         if(posTicket == ticket)
         {
            offen = true;
            break;
         }
      }
      
      if(!offen)
      {
         PrintFormat("🗑️ Position %d geschlossen - aus Tracking entfernt", ticket);
         RemovePositionFromTracking(ticket);
      }
   }
   
   // Clean up partial profit tracking
   for(int i = ArraySize(partialProfits) - 1; i >= 0; i--)
   {
      ulong ticket = partialProfits[i].ticket;
      bool offen = false;
      
      for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
      {
         ulong posTicket = PositionGetTicket(pos);
         if(posTicket == ticket)
         {
            offen = true;
            break;
         }
      }
      
      if(!offen)
      {
         RemovePartialProfitTracking(ticket);
      }
   }
}

//+------------------------------------------------------------------+

void OnTick()
{
   // Cleanup closed positions from tracking
   CleanupClosedPositions();
   
   // Check if new trading day
   datetime heute = DateOfDay(TimeCurrent());
   if(heute != lastTradeDay)
   {
      lastTradeDay = heute;
      LongTradesToday = 0;
      ShortTradesToday = 0;
      dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      Print("🔄 Neuer Handelstag - Zähler und Balance zurückgesetzt");
   }
   
   // Check risk management limits
   if(!CheckDailyLoss())
   {
      Print("⚠️ Tägliches Verlustlimit erreicht - Handel gestoppt");
      return;
   }
   
   if(!CheckMaxDrawdown())
   {
      Print("⚠️ Maximaler Drawdown erreicht - Handel gestoppt");
      return;
   }
   
   // Manage existing positions first
   ManagePartialProfits();
   VerwalteTrailingTakeProfitUndStopLoss();
   PrüfeUndSchließePositionen();
   
   // Analyze market for new entries
   TradeSignal signal = AnalysiereMarkt();
   
   // Execute buy signal
   if(signal == SIGNAL_BUY && LongTradesToday < MaxLongPositions)
   {
      double lot = 0;
      if(UseATRPositionSizing)
      {
         double entryPrice = SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);
         double atr = GetATR();
         if(entryPrice > 0 && atr > 0)
         {
            double stopLoss = entryPrice - (atr * ATRMultiplier);
            lot = CalculatePositionSize(entryPrice, stopLoss);
         }
      }
      else
      {
         lot = BerechneLotMitProzent(RiskPerTrade);
      }
      
      if(lot > 0 && Kaufe(lot))
      {
         LongTradesToday++;
         PrintFormat("🟢 Long Position eröffnet. Heute: %d/%d", LongTradesToday, MaxLongPositions);
      }
   }
   
   // Execute sell signal
   if(signal == SIGNAL_SELL && ShortTradesToday < MaxShortPositions)
   {
      double lot = 0;
      if(UseATRPositionSizing)
      {
         double entryPrice = SymbolInfoDouble(TradeSymbol, SYMBOL_BID);
         double atr = GetATR();
         if(entryPrice > 0 && atr > 0)
         {
            double stopLoss = entryPrice + (atr * ATRMultiplier);
            lot = CalculatePositionSize(entryPrice, stopLoss);
         }
      }
      else
      {
         lot = BerechneLotMitProzent(RiskPerTrade);
      }
      
      if(lot > 0 && ÖffneShort(lot))
      {
         ShortTradesToday++;
         PrintFormat("🔴 Short Position eröffnet. Heute: %d/%d", ShortTradesToday, MaxShortPositions);
      }
   }
}

//+------------------------------------------------------------------+

datetime DateOfDay(datetime dt)

{

MqlDateTime t;

TimeToStruct(dt, t);

t.hour = 0; t.min = 0; t.sec = 0;

return StructToTime(t);

}

//+------------------------------------------------------------------+

// === RISK MANAGEMENT FUNCTIONS ===

bool CheckDailyLoss()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyLoss = (dailyStartBalance - currentBalance) / dailyStartBalance * 100.0;
   return dailyLoss < MaxDailyLoss;
}

bool CheckMaxDrawdown()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double totalDrawdown = (totalStartBalance - currentBalance) / totalStartBalance * 100.0;
   return totalDrawdown < MaxDrawdown;
}

double GetATR()
{
   double atr[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) return 0;
   return atr[0];
}

double GetATRPercent()
{
   double atr = GetATR();
   double price = SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);
   if(price <= 0 || atr <= 0) return 0;
   return (atr / price) * 100.0;
}

bool IsVolatilityAcceptable()
{
   double atrPct = GetATRPercent();
   return (atrPct >= MinVolatility && atrPct <= MaxVolatility);
}

bool IsTimeFilterOK()
{
   if(!UseTimeFilter) return true;
   
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   return (time.hour >= TradingStartHour && time.hour <= TradingEndHour);
}

double CalculatePositionSize(double entryPrice, double stopLoss)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPerTrade / 100.0);
   
   if(entryPrice <= 0 || stopLoss <= 0) return 0;
   
   double priceDiff = MathAbs(entryPrice - stopLoss);
   if(priceDiff <= 0) return 0;
   
   double lot = riskAmount / priceDiff;
   
   // Apply symbol constraints
   double step = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_STEP);
   double min = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MAX);
   
   lot = MathFloor(lot / step) * step;
   lot = MathMax(min, MathMin(max, lot));
   
   return lot;
}

double BerechneLotMitProzent(double prozent)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double einsatz = balance * (prozent / 100.0);
   double preis = SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);
   
   if(preis <= 0 || einsatz <= 0) return 0;
   
   double lot = einsatz / preis;
   double step = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_STEP);
   double min = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MAX);
   
   lot = MathFloor(lot / step) * step;
   lot = MathMax(min, MathMin(max, lot));
   
   return lot;
}

//+------------------------------------------------------------------+

bool Kaufe(double lot)
{
   double entryPrice = SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);
   if(entryPrice <= 0) return false;
   
   // Calculate stop loss using ATR
   double atr = GetATR();
   double stopLoss = 0;
   
   if(UseATRPositionSizing && atr > 0)
   {
      stopLoss = entryPrice - (atr * ATRMultiplier);
      // Recalculate lot size based on risk
      lot = CalculatePositionSize(entryPrice, stopLoss);
   }
   
   if(lot <= 0) return false;
   
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = TradeSymbol;
   request.volume = lot;
   request.type = ORDER_TYPE_BUY;
   request.price = entryPrice;
   request.sl = stopLoss;
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.type_filling = ORDER_FILLING_IOC;
   
   if(!OrderSend(request, result))
   {
      PrintFormat("❌ OrderSend fehlgeschlagen (Buy): %d", GetLastError());
      return false;
   }
   
   if(result.retcode != TRADE_RETCODE_DONE)
   {
      PrintFormat("❌ OrderSend Retcode (Buy): %d", result.retcode);
      return false;
   }
   
   // Add to partial profit tracking
   if(UsePartialProfits && result.order > 0)
   {
      int size = ArraySize(partialProfits);
      ArrayResize(partialProfits, size + 1);
      partialProfits[size].ticket = result.order;
      partialProfits[size].level1Taken = false;
      partialProfits[size].level2Taken = false;
      partialProfits[size].originalVolume = lot;
   }
   
   PrintFormat("🟢 Long geöffnet: %.2f @ %.5f, SL: %.5f", lot, entryPrice, stopLoss);
   return true;
}

bool ÖffneShort(double lot)
{
   double entryPrice = SymbolInfoDouble(TradeSymbol, SYMBOL_BID);
   if(entryPrice <= 0) return false;
   
   // Calculate stop loss using ATR
   double atr = GetATR();
   double stopLoss = 0;
   
   if(UseATRPositionSizing && atr > 0)
   {
      stopLoss = entryPrice + (atr * ATRMultiplier);
      // Recalculate lot size based on risk
      lot = CalculatePositionSize(entryPrice, stopLoss);
   }
   
   if(lot <= 0) return false;
   
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = TradeSymbol;
   request.volume = lot;
   request.type = ORDER_TYPE_SELL;
   request.price = entryPrice;
   request.sl = stopLoss;
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.type_filling = ORDER_FILLING_IOC;
   
   if(!OrderSend(request, result))
   {
      PrintFormat("❌ OrderSend fehlgeschlagen (Sell): %d", GetLastError());
      return false;
   }
   
   if(result.retcode != TRADE_RETCODE_DONE)
   {
      PrintFormat("❌ OrderSend Retcode (Sell): %d", result.retcode);
      return false;
   }
   
   // Add to partial profit tracking
   if(UsePartialProfits && result.order > 0)
   {
      int size = ArraySize(partialProfits);
      ArrayResize(partialProfits, size + 1);
      partialProfits[size].ticket = result.order;
      partialProfits[size].level1Taken = false;
      partialProfits[size].level2Taken = false;
      partialProfits[size].originalVolume = lot;
   }
   
   PrintFormat("🔴 Short geöffnet: %.2f @ %.5f, SL: %.5f", lot, entryPrice, stopLoss);
   return true;
}

//+------------------------------------------------------------------+

void PrüfeUndSchließePositionen()

{

for(int i = PositionsTotal() - 1; i >= 0; i--)

{

ulong ticket = PositionGetTicket(i);

  if(!PositionSelectByTicket(ticket)) continue;

  if(PositionGetString(POSITION_SYMBOL) != TradeSymbol) continue;

  if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;



  ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

  double entry = PositionGetDouble(POSITION_PRICE_OPEN);

  double vol = PositionGetDouble(POSITION_VOLUME);

  double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(TradeSymbol, SYMBOL_BID)

                                             : SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);

  if(price <= 0) continue;



  // Kein festes Gewinnziel mehr, daher keine automatische Schließung hier

}

}

//+------------------------------------------------------------------+

//| Trailing Take Profit & Trailing Stop Loss |

//+------------------------------------------------------------------+

// === PARTIAL PROFIT FUNCTIONS ===

int FindPartialProfitIndex(ulong ticket)
{
   for(int i = 0; i < ArraySize(partialProfits); i++)
      if(partialProfits[i].ticket == ticket)
         return i;
   return -1;
}

void RemovePartialProfitTracking(ulong ticket)
{
   int idx = FindPartialProfitIndex(ticket);
   if(idx == -1) return;
   
   for(int i = idx; i < ArraySize(partialProfits) - 1; i++)
      partialProfits[i] = partialProfits[i + 1];
      
   ArrayResize(partialProfits, ArraySize(partialProfits) - 1);
}

bool ClosePartialPosition(ulong ticket, double percentage)
{
   if(!PositionSelectByTicket(ticket)) return false;
   
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   double closeVolume = currentVolume * (percentage / 100.0);
   
   // Adjust to symbol volume step
   double step = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_STEP);
   closeVolume = MathFloor(closeVolume / step) * step;
   
   if(closeVolume < SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MIN))
      return false;
      
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = TradeSymbol;
   request.volume = closeVolume;
   request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(TradeSymbol, SYMBOL_BID) : 
                                                   SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.type_filling = ORDER_FILLING_IOC;
   
   if(!OrderSend(request, result) || result.retcode != TRADE_RETCODE_DONE)
   {
      PrintFormat("❌ Fehler beim Teilgewinnmitnahme: %d", result.retcode);
      return false;
   }
   
   PrintFormat("🟡 Teilgewinn mitgenommen: %.2f%% von Position %d", percentage, ticket);
   return true;
}

void ManagePartialProfits()
{
   if(!UsePartialProfits) return;
   
   for(int i = 0; i < ArraySize(partialProfits); i++)
   {
      ulong ticket = partialProfits[i].ticket;
      
      if(!PositionSelectByTicket(ticket))
      {
         RemovePartialProfitTracking(ticket);
         i--; // Adjust index after removal
         continue;
      }
      
      if(PositionGetString(POSITION_SYMBOL) != TradeSymbol ||
         PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
         
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(TradeSymbol, SYMBOL_BID) :
                                                   SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);
                                                   
      if(price <= 0) continue;
      
      double profitPct = (type == POSITION_TYPE_BUY) ? 
                        ((price - entry) / entry * 100.0) :
                        ((entry - price) / entry * 100.0);
      
      // First partial profit level
      if(!partialProfits[i].level1Taken && profitPct >= PartialProfit1Pct)
      {
         if(ClosePartialPosition(ticket, PartialSize1))
            partialProfits[i].level1Taken = true;
      }
      
      // Second partial profit level
      if(!partialProfits[i].level2Taken && profitPct >= PartialProfit2Pct)
      {
         if(ClosePartialPosition(ticket, PartialSize2))
            partialProfits[i].level2Taken = true;
      }
   }
}

void VerwalteTrailingTakeProfitUndStopLoss()
{
   double atr = GetATR();
   if(atr <= 0) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != TradeSymbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(TradeSymbol, SYMBOL_BID) :
                                                   SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);
                                                   
      if(price <= 0) continue;
      
      double profitPct = (type == POSITION_TYPE_BUY) ?
                        ((price - entry) / entry * 100.0) :
                        ((entry - price) / entry * 100.0);
      
      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      
      if(type == POSITION_TYPE_BUY)
      {
         // Update highest price for this position
         double highestPrice = GetHighForPosition(ticket);
         if(price > highestPrice)
            UpdateHighLowForPosition(ticket, type, price);
         highestPrice = GetHighForPosition(ticket);
         
         // Move to breakeven
         if(profitPct >= BreakevenProfitPct && (currentSL == 0 || currentSL < entry))
         {
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.symbol = TradeSymbol;
            request.sl = entry;
            request.tp = PositionGetDouble(POSITION_TP);
            
            if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
               PrintFormat("⚖️ Breakeven SL gesetzt (Long): %.5f Ticket %d", entry, ticket);
         }
         // Trailing stop
         else if(profitPct >= TrailingStartPct)
         {
            double trailingDistance = atr * TrailingStepATR;
            double newSL = highestPrice - trailingDistance;
            
            if(newSL > currentSL && newSL < price)
            {
               request.action = TRADE_ACTION_SLTP;
               request.position = ticket;
               request.symbol = TradeSymbol;
               request.sl = newSL;
               request.tp = PositionGetDouble(POSITION_TP);
               
               if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
                  PrintFormat("🔄 ATR Trailing SL (Long): %.5f Ticket %d", newSL, ticket);
            }
         }
      }
      else // SHORT position
      {
         // Update lowest price for this position
         double lowestPrice = GetLowForPosition(ticket);
         if(price < lowestPrice)
            UpdateHighLowForPosition(ticket, type, price);
         lowestPrice = GetLowForPosition(ticket);
         
         // Move to breakeven
         if(profitPct >= BreakevenProfitPct && (currentSL == 0 || currentSL > entry))
         {
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.symbol = TradeSymbol;
            request.sl = entry;
            request.tp = PositionGetDouble(POSITION_TP);
            
            if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
               PrintFormat("⚖️ Breakeven SL gesetzt (Short): %.5f Ticket %d", entry, ticket);
         }
         // Trailing stop
         else if(profitPct >= TrailingStartPct)
         {
            double trailingDistance = atr * TrailingStepATR;
            double newSL = lowestPrice + trailingDistance;
            
            if((currentSL == 0 || newSL < currentSL) && newSL > price)
            {
               request.action = TRADE_ACTION_SLTP;
               request.position = ticket;
               request.symbol = TradeSymbol;
               request.sl = newSL;
               request.tp = PositionGetDouble(POSITION_TP);
               
               if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
                  PrintFormat("🔄 ATR Trailing SL (Short): %.5f Ticket %d", newSL, ticket);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+

enum TradeSignal { SIGNAL_NONE, SIGNAL_BUY, SIGNAL_SELL };

// === TREND ANALYSIS FUNCTIONS ===

bool IsTrendBullish()
{
   double ema20[], ema50[], ema200[];
   if(CopyBuffer(ema20Handle, 0, 0, 1, ema20) <= 0 ||
      CopyBuffer(ema50Handle, 0, 0, 1, ema50) <= 0 ||
      CopyBuffer(ema200Handle, 0, 0, 1, ema200) <= 0)
      return false;
      
   return (ema20[0] > ema50[0] && ema50[0] > ema200[0]);
}

bool IsTrendBearish()
{
   double ema20[], ema50[], ema200[];
   if(CopyBuffer(ema20Handle, 0, 0, 1, ema20) <= 0 ||
      CopyBuffer(ema50Handle, 0, 0, 1, ema50) <= 0 ||
      CopyBuffer(ema200Handle, 0, 0, 1, ema200) <= 0)
      return false;
      
   return (ema20[0] < ema50[0] && ema50[0] < ema200[0]);
}

bool IsHigherTimeframeBullish()
{
   double rsiH4[], emaH4_20[], emaH4_50[];
   if(CopyBuffer(rsiH4Handle, 0, 0, 1, rsiH4) <= 0 ||
      CopyBuffer(emaH4_20Handle, 0, 0, 1, emaH4_20) <= 0 ||
      CopyBuffer(emaH4_50Handle, 0, 0, 1, emaH4_50) <= 0)
      return false;
      
   return (emaH4_20[0] > emaH4_50[0] && rsiH4[0] > 45);
}

bool IsHigherTimeframeBearish()
{
   double rsiH4[], emaH4_20[], emaH4_50[];
   if(CopyBuffer(rsiH4Handle, 0, 0, 1, rsiH4) <= 0 ||
      CopyBuffer(emaH4_20Handle, 0, 0, 1, emaH4_20) <= 0 ||
      CopyBuffer(emaH4_50Handle, 0, 0, 1, emaH4_50) <= 0)
      return false;
      
   return (emaH4_20[0] < emaH4_50[0] && rsiH4[0] < 55);
}

bool IsTrendStrong()
{
   double adx[];
   if(CopyBuffer(adxHandle, 0, 0, 1, adx) <= 0)
      return false;
      
   return adx[0] > 25;
}

bool HasVolumeConfirmation()
{
   if(!UseVolumeFilter) return true;
   
   // For crypto, we check if current volatility is above average
   double atrCurrent = GetATR();
   double atrPrevious[];
   if(CopyBuffer(atrHandle, 0, 1, 5, atrPrevious) <= 0)
      return true;
      
   double avgATR = 0;
   for(int i = 0; i < 5; i++)
      avgATR += atrPrevious[i];
   avgATR /= 5;
   
   return atrCurrent > avgATR * 1.1; // Current ATR should be 10% above average
}

TradeSignal AnalysiereMarkt()
{
   // Check basic filters first
   if(!IsTimeFilterOK() || !IsVolatilityAcceptable())
      return SIGNAL_NONE;
      
   // Get basic indicators
   double rsi[], macd[], signal[], ema20[], price[];
   if(CopyBuffer(rsiHandle, 0, 0, 2, rsi) <= 0 ||
      CopyBuffer(macdHandle, 0, 0, 2, macd) <= 0 ||
      CopyBuffer(macdHandle, 1, 0, 2, signal) <= 0 ||
      CopyBuffer(ema20Handle, 0, 0, 1, ema20) <= 0)
      return SIGNAL_NONE;
      
   double currentPrice = SymbolInfoDouble(TradeSymbol, SYMBOL_BID);
   if(currentPrice <= 0) return SIGNAL_NONE;
   
   // Check trend strength
   if(!IsTrendStrong()) return SIGNAL_NONE;
   
   // Check volume confirmation
   if(!HasVolumeConfirmation()) return SIGNAL_NONE;
   
   // Enhanced Buy Signal
   bool buySignal = false;
   if(rsi[0] < 35 && rsi[0] > rsi[1] &&              // RSI oversold but improving
      macd[0] > signal[0] && macd[1] <= signal[1] && // MACD crossover
      currentPrice > ema20[0])                       // Price above EMA20
   {
      if(!UseTrendFilter || (IsTrendBullish() && IsHigherTimeframeBullish()))
         buySignal = true;
   }
   
   // Enhanced Sell Signal  
   bool sellSignal = false;
   if(rsi[0] > 65 && rsi[0] < rsi[1] &&              // RSI overbought but declining
      macd[0] < signal[0] && macd[1] >= signal[1] && // MACD crossover
      currentPrice < ema20[0])                       // Price below EMA20
   {
      if(!UseTrendFilter || (IsTrendBearish() && IsHigherTimeframeBearish()))
         sellSignal = true;
   }
   
   if(buySignal) return SIGNAL_BUY;
   if(sellSignal) return SIGNAL_SELL;
   
   return SIGNAL_NONE;
}

