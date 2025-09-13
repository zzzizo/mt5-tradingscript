# MT5 Trading Bot

An advanced automated trading Expert Advisor (EA) for MetaTrader 5 that trades cryptocurrency pairs using multiple indicators, multi-timeframe analysis, and sophisticated risk management.

## Features

- **Advanced Automated Trading**: Multi-indicator strategy with RSI, MACD, EMA, ADX, and ATR
- **Multi-Timeframe Analysis**: M1 execution with H4 trend confirmation
- **Enhanced Risk Management**: ATR-based position sizing, daily loss limits, max drawdown protection
- **Partial Profit Taking**: Configurable profit levels with automatic position reduction
- **Advanced Trailing Stops**: ATR-based trailing with breakeven protection
- **Trading Filters**: Time-based, volatility, trend, and volume filters
- **Position Limits**: Daily limits for long and short positions with balance tracking

## Trading Strategy

### Enhanced Entry Signals
- **Buy Signal**: RSI < 35 (improving), MACD crossover above signal, price above EMA20
- **Sell Signal**: RSI > 65 (declining), MACD crossover below signal, price below EMA20
- **Trend Filter**: EMA alignment (20 > 50 > 200 for bullish, reverse for bearish)
- **Multi-Timeframe**: H4 trend confirmation with RSI and EMA analysis
- **Volume Filter**: ATR-based volatility confirmation
- **Strength Filter**: ADX > 25 for trend strength

### Advanced Risk Management
- **Position Sizing**: ATR-based or percentage-based (default: 2% of balance)
- **Daily Loss Limit**: Maximum 10% daily drawdown protection
- **Total Drawdown**: Maximum 20% total account drawdown protection
- **Daily Position Limits**: Maximum 5 long and 5 short positions per day
- **Volatility Range**: Trading only within 0.5% - 5% ATR range
- **Time Filter**: Trading hours 8:00 - 22:00 (broker time)

### Partial Profit Management
- **Level 1**: 30% position closure at 2% profit
- **Level 2**: 30% position closure at 4% profit
- **Remaining 40%**: Managed by trailing stops

### Advanced Trailing System
- **Breakeven**: Move stop to entry at 1.5% profit
- **ATR Trailing**: Starts at 3% profit, trails at 1.5x ATR distance
- **Dynamic Adjustment**: Based on highest/lowest prices reached

## Configuration

### Input Parameters

#### Trading Parameters
- `TradeSymbol`: Trading pair (default: "BTCUSDT")
- `RiskPerTrade`: Risk percentage per trade (default: 2.0%)
- `Slippage`: Maximum slippage in points (default: 100)
- `MagicNumber`: Unique EA identifier (default: 123456)
- `MaxLongPositions`: Daily long position limit (default: 5)
- `MaxShortPositions`: Daily short position limit (default: 5)

#### Risk Management
- `MaxDailyLoss`: Maximum daily loss percentage (default: 10.0%)
- `MaxDrawdown`: Maximum total drawdown percentage (default: 20.0%)
- `UseATRPositionSizing`: Enable ATR-based sizing (default: true)
- `ATRMultiplier`: ATR multiplier for stop loss (default: 2.0)

#### Entry Filters
- `UseTrendFilter`: Only trade with trend (default: true)
- `UseVolumeFilter`: Require volume confirmation (default: true)
- `MinVolatility`: Minimum ATR percentage (default: 0.5%)
- `MaxVolatility`: Maximum ATR percentage (default: 5.0%)

#### Trailing Stops
- `BreakevenProfitPct`: Breakeven trigger (default: 1.5%)
- `TrailingStartPct`: Trailing start profit (default: 3.0%)
- `TrailingStepATR`: Trailing distance in ATR (default: 1.5)

#### Time Filters
- `UseTimeFilter`: Enable time filtering (default: true)
- `TradingStartHour`: Start trading hour (default: 8)
- `TradingEndHour`: End trading hour (default: 22)

#### Partial Profits
- `UsePartialProfits`: Enable partial profits (default: true)
- `PartialProfit1Pct`: First profit level (default: 2.0%)
- `PartialProfit2Pct`: Second profit level (default: 4.0%)
- `PartialSize1`: First closure percentage (default: 30.0%)
- `PartialSize2`: Second closure percentage (default: 30.0%)

## Installation

1. **Download MetaTrader 5** from [metatrader5.com](https://www.metatrader5.com/en/download)
2. **Copy `script.mq5`** to your MT5 data folder:
   ```
   C:\Users\[Username]\AppData\Roaming\MetaQuotes\Terminal\[TerminalID]\MQL5\Experts\
   ```
3. **Compile** the script in MetaEditor (F4 → F7)
4. **Attach to chart**: Drag from Navigator → Expert Advisors onto your trading chart
5. **Enable AutoTrading** (green button in MT5 toolbar)

## Requirements

- MetaTrader 5 platform
- Broker that supports cryptocurrency trading (for BTCUSDT)
- Sufficient account balance for position sizing
- Stable internet connection

## Usage

1. Open BTCUSDT chart (or modify `TradeSymbol` for other pairs)
2. Attach the EA to the chart
3. Configure input parameters as needed
4. Enable AutoTrading
5. Monitor performance and adjust settings

## Important Notes

⚠️ **Risk Warning**: 
- Always test on demo account first
- Cryptocurrency markets are highly volatile
- Past performance doesn't guarantee future results
- Never risk more than you can afford to lose

⚠️ **Broker Compatibility**:
- Ensure your broker offers the trading symbol
- Some brokers use different symbol names (e.g., BTCUSD instead of BTCUSDT)
- Modify the `TradeSymbol` parameter accordingly

## Customization

To modify the trading strategy:
- Edit the `AnalysiereMarkt()` function for different entry conditions and filters
- Adjust trailing stop logic in `VerwalteTrailingTakeProfitUndStopLoss()` for ATR-based trailing
- Modify position sizing in `CalculatePositionSize()` for ATR-based sizing or `BerechneLotMitProzent()` for percentage-based
- Configure partial profit levels in `ManagePartialProfits()`
- Adjust multi-timeframe analysis in trend filter functions
- Modify risk management limits in `CheckDailyLoss()` and `CheckMaxDrawdown()`

## Support

For issues or questions:
- Check MetaTrader 5 documentation
- Verify broker symbol compatibility
- Test on demo account before live trading

## License

This project is open source. Use at your own risk.

---

**Disclaimer**: This trading bot is for educational purposes. Trading involves substantial risk and may not be suitable for all investors.
