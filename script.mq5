
#property strict

input string TradeSymbol = "BTCUSDT";

input double KapitalProzent = 5.0;

input int Slippage = 100;

input int MagicNumber = 123456;

input int MaxLongPositions = 10;

input int MaxShortPositions = 10;

datetime lastTradeDay = 0;

int LongTradesToday = 0;

int ShortTradesToday = 0;

int rsiHandle = INVALID_HANDLE;

int macdHandle = INVALID_HANDLE;

// Arrays für Positionstracking

ulong positionTickets[];

double highestPriceLongMap[];

double lowestPriceShortMap[];

//+------------------------------------------------------------------+

//| Initialisierung |

//+------------------------------------------------------------------+

int OnInit()

{

rsiHandle = iRSI(TradeSymbol, PERIOD_M1, 14, PRICE_CLOSE);

macdHandle = iMACD(TradeSymbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE);

if(rsiHandle == INVALID_HANDLE || macdHandle == INVALID_HANDLE)

{

Print("❌ Fehler beim Erstellen der Indikatorenhandles");

  return(INIT_FAILED);

}

Print("✅ Indikatorenhandles erfolgreich erstellt");

return(INIT_SUCCEEDED);

}

//+------------------------------------------------------------------+

void OnDeinit(const int reason)

{

if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);

if(macdHandle != INVALID_HANDLE) IndicatorRelease(macdHandle);

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

}

//+------------------------------------------------------------------+

void OnTick()

{

CleanupClosedPositions();

datetime heute = DateOfDay(TimeCurrent());

if(heute != lastTradeDay)

{

lastTradeDay = heute;

  LongTradesToday = 0;

  ShortTradesToday = 0;

  Print("🔄 Neuer Handelstag - Tageszähler zurückgesetzt");

}

TradeSignal signal = AnalysiereMarkt();

if(signal == SIGNAL_BUY && LongTradesToday < MaxLongPositions)

{

double lot = BerechneLotMitProzent(KapitalProzent);

  if(lot > 0 && Kaufe(lot)) LongTradesToday++;

}

if(signal == SIGNAL_SELL && ShortTradesToday < MaxShortPositions)

{

double lot = BerechneLotMitProzent(KapitalProzent);

  if(lot > 0 && ÖffneShort(lot)) ShortTradesToday++;

}

PrüfeUndSchließePositionen();

VerwalteTrailingTakeProfitUndStopLoss();

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

double preis = SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);

MqlTradeRequest request;

MqlTradeResult result;

ZeroMemory(request); ZeroMemory(result);

request.action = TRADE_ACTION_DEAL;

request.symbol = TradeSymbol;

request.volume = lot;

request.type = ORDER_TYPE_BUY;

request.price = preis;

request.deviation = Slippage;

request.magic = MagicNumber;

request.type_filling= ORDER_FILLING_IOC;

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

PrintFormat("🟢 Long geöffnet: %.2f @ %.5f", lot, preis);

return true;

}

bool ÖffneShort(double lot)

{

double preis = SymbolInfoDouble(TradeSymbol, SYMBOL_BID);

MqlTradeRequest request;

MqlTradeResult result;

ZeroMemory(request); ZeroMemory(result);

request.action = TRADE_ACTION_DEAL;

request.symbol = TradeSymbol;

request.volume = lot;

request.type = ORDER_TYPE_SELL;

request.price = preis;

request.deviation = Slippage;

request.magic = MagicNumber;

request.type_filling= ORDER_FILLING_IOC;

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

PrintFormat("🔴 Short geöffnet: %.2f @ %.5f", lot, preis);

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

void VerwalteTrailingTakeProfitUndStopLoss()

{

for(int i = PositionsTotal() - 1; i >= 0; i--)

{

ulong ticket = PositionGetTicket(i);

  if(!PositionSelectByTicket(ticket)) continue;

  if(PositionGetString(POSITION_SYMBOL) != TradeSymbol) continue;

  if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;



  ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

  double entry = PositionGetDouble(POSITION_PRICE_OPEN);

  double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(TradeSymbol, SYMBOL_BID)

                                             : SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);

  if(price <= 0) continue;



  double profitPct = (type == POSITION_TYPE_BUY)

                     ? (price - entry) / entry * 100.0

                     : (entry - price) / entry * 100.0;



  MqlTradeRequest request;

  MqlTradeResult result;

  ZeroMemory(request);

  ZeroMemory(result);



  if(type == POSITION_TYPE_BUY)

  {

     double highestPriceLong = GetHighForPosition(ticket);

     if(price > highestPriceLong)

        UpdateHighLowForPosition(ticket, type, price);



     highestPriceLong = GetHighForPosition(ticket);



     if(profitPct >= 5.0)

     {

        double newTP = highestPriceLong * 0.99;



        double oldTP = PositionGetDouble(POSITION_TP);

        if(oldTP == 0 || newTP > oldTP)

        {

           request.action = TRADE_ACTION_SLTP;

           request.position = ticket;

           request.symbol = TradeSymbol;

           request.tp = newTP;

           request.sl = 0;

           if(!OrderSend(request, result) || result.retcode != TRADE_RETCODE_DONE)

              PrintFormat("❌ Fehler TP aktualisieren (Long) Ticket %d: %d", ticket, result.retcode);

           else

              PrintFormat("🔄 Trailing TP aktualisiert (Long): %.5f Ticket %d", newTP, ticket);

        }

     }



     if(profitPct >= 4.0)

     {

        double tp = PositionGetDouble(POSITION_TP);

        if(tp > 0)

        {

           double newSL = tp * 0.99;



           double oldSL = PositionGetDouble(POSITION_SL);

           if(oldSL == 0 || newSL > oldSL)

           {

              request.action = TRADE_ACTION_SLTP;

              request.position = ticket;

              request.symbol = TradeSymbol;

              request.sl = newSL;

              request.tp = tp;

              if(!OrderSend(request, result) || result.retcode != TRADE_RETCODE_DONE)

                 PrintFormat("❌ Fehler SL aktualisieren (Long) Ticket %d: %d", ticket, result.retcode);

              else

                 PrintFormat("🔄 Trailing SL aktualisiert (Long): %.5f Ticket %d", newSL, ticket);

           }

        }

     }

  }

  else

  {

     double lowestPriceShort = GetLowForPosition(ticket);

     if(price < lowestPriceShort)

        UpdateHighLowForPosition(ticket, type, price);



     lowestPriceShort = GetLowForPosition(ticket);



     if(profitPct >= 5.0)

     {

        double newTP = lowestPriceShort * 1.01;



        double oldTP = PositionGetDouble(POSITION_TP);

        if(oldTP == 0 || newTP < oldTP)

        {

           request.action = TRADE_ACTION_SLTP;

           request.position = ticket;

           request.symbol = TradeSymbol;

           request.tp = newTP;

           request.sl = 0;

           if(!OrderSend(request, result) || result.retcode != TRADE_RETCODE_DONE)

              PrintFormat("❌ Fehler TP aktualisieren (Short) Ticket %d: %d", ticket, result.retcode);

           else

              PrintFormat("🔄 Trailing TP aktualisiert (Short): %.5f Ticket %d", newTP, ticket);

        }

     }



     if(profitPct >= 4.0)

     {

        double tp = PositionGetDouble(POSITION_TP);

        if(tp > 0)

        {

           double newSL = tp * 1.01;



           double oldSL = PositionGetDouble(POSITION_SL);

           if(oldSL == 0 || newSL < oldSL)

           {

              request.action = TRADE_ACTION_SLTP;

              request.position = ticket;

              request.symbol = TradeSymbol;

              request.sl = newSL;

              request.tp = tp;

              if(!OrderSend(request, result) || result.retcode != TRADE_RETCODE_DONE)

                 PrintFormat("❌ Fehler SL aktualisieren (Short) Ticket %d: %d", ticket, result.retcode);

              else

                 PrintFormat("🔄 Trailing SL aktualisiert (Short): %.5f Ticket %d", newSL, ticket);

           }

        }

     }

  }

}

}

//+------------------------------------------------------------------+

enum TradeSignal { SIGNAL_NONE, SIGNAL_BUY, SIGNAL_SELL };

TradeSignal AnalysiereMarkt()

{

double rsi[], macd[], signal[];

if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0 ||

CopyBuffer(macdHandle, 0, 0, 1, macd) <= 0 ||

  CopyBuffer(macdHandle, 1, 0, 1, signal) <= 0)

  return SIGNAL_NONE;

if(rsi[0] < 30 && macd[0] > signal[0]) return SIGNAL_BUY;

if(rsi[0] > 70 && macd[0] < signal[0]) return SIGNAL_SELL;

return SIGNAL_NONE;

}

