import os
import sys
import pandas as pd
import numpy as np
import MetaTrader5 as mt5

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

def scan_all():
    if not mt5.initialize():
        print("MT5 init failed")
        return
        
    for sym in ["XAUUSD", "BTCUSD"]:
        for tf, tf_name in [(mt5.TIMEFRAME_M1, "M1"), (mt5.TIMEFRAME_M5, "M5"), (mt5.TIMEFRAME_M15, "M15")]:
            rates = mt5.copy_rates_from_pos(sym, tf, 0, 100)
            if rates is None or len(rates) < 50:
                continue
            df = pd.DataFrame(rates)
            df['ema9'] = df['close'].ewm(span=9, adjust=False).mean()
            df['ema20'] = df['close'].ewm(span=20, adjust=False).mean()
            df['ema50'] = df['close'].ewm(span=50, adjust=False).mean()
            
            delta = df['close'].diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
            rs = gain / (loss + 1e-9)
            df['rsi'] = 100 - (100 / (1 + rs))
            
            cur_close = df['close'].iloc[-1]
            cur_rsi = df['rsi'].iloc[-1]
            trend_dir = "BULLISH" if df['ema9'].iloc[-1] > df['ema20'].iloc[-1] > df['ema50'].iloc[-1] else ("BEARISH" if df['ema9'].iloc[-1] < df['ema20'].iloc[-1] < df['ema50'].iloc[-1] else "MIXED/CONSOLIDATION")
            
            recent_high = df['high'].iloc[-20:].max()
            recent_low = df['low'].iloc[-20:].min()
            eq = (recent_high + recent_low) / 2.0
            zone = "DISCOUNT" if cur_close < eq else "PREMIUM"
            
            print(f"{sym:<6} | {tf_name:<3} | Price: {cur_close:<9.2f} | Trend: {trend_dir:<19} | RSI: {cur_rsi:4.1f} | Zone: {zone}")
    mt5.shutdown()

if __name__ == "__main__":
    scan_all()
