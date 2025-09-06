# MT5 Trading Bo

An automated trading Expert Advisor (EA) for MetaTrader 5 that trades cryptocurrency pairs using RSI and MACD indicators.

## Features

- **Automated Trading**: Uses RSI and MACD indicators for entry signals
- **Risk Management**: Configurable position sizing based on account percentage
- **Trailing Stops**: Dynamic take profit and stop loss management
- **Position Limits**: Daily limits for long and short positions
- **Multi-timeframe**: Works on M1 timeframe for high-frequency trading

## Trading Strategy

### Entry Signals
- **Buy Signal**: RSI < 30 AND MACD line above signal line
- **Sell Signal**: RSI > 70 AND MACD line below signal line

### Risk Management
- **Position Size**: 5% of account balance per trade (configurable)
- **Daily Limits**: Maximum 10 long positions and 10 short positions per day
- **Trailing Take Profit**: Activated at 5% profit, trails at 99% of highest/lowest price
- **Trailing Stop Loss**: Activated at 4% profit, set to 99% of take profit level

## Configuration

### Input Parameters
- `TradeSymbol`: Trading pair (default: "BTCUSDT")
- `KapitalProzent`: Risk percentage per trade (default: 5.0%)
- `Slippage`: Maximum slippage in points (default: 100)
- `MagicNumber`: Unique EA identifier (default: 123456)
- `MaxLongPositions`: Daily long position limit (default: 10)
- `MaxShortPositions`: Daily short position limit (default: 10)

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
- Edit the `AnalysiereMarkt()` function for different entry conditions
- Adjust trailing stop percentages in `VerwalteTrailingTakeProfitUndStopLoss()`
- Change position sizing logic in `BerechneLotMitProzent()`

## Support

For issues or questions:
- Check MetaTrader 5 documentation
- Verify broker symbol compatibility
- Test on demo account before live trading

## License

This project is open source. Use at your own risk.

---

**Disclaimer**: This trading bot is for educational purposes. Trading involves substantial risk and may not be suitable for all investors.
