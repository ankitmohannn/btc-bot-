import os
import pandas as pd
import numpy as np
import MetaTrader5 as mt5

if not mt5.initialize():
    print("MT5 Init Error")
    exit()

rates = mt5.copy_rates_from_pos("BTCUSD", mt5.TIMEFRAME_M5, 0, 50)
df = pd.DataFrame(rates)
df['tr'] = np.maximum(df['high'] - df['low'], 
                      np.maximum(abs(df['high'] - df['close'].shift(1)), 
                                 abs(df['low'] - df['close'].shift(1))))
df['atr14'] = df['tr'].rolling(14).mean()

cur_close = df['close'].iloc[-1]
cur_atr = df['atr14'].iloc[-1]
prev_low = df['low'].iloc[-5:].min()
swing_sl_dist = cur_close - prev_low

print(f"BTCUSD Current Price : ${cur_close:.2f}")
print(f"5-Minute ATR (14)    : ${cur_atr:.2f}")
print(f"ATR x 1.5 Multiplier : ${cur_atr * 1.5:.2f}")
print(f"Swing Low Distance   : ${swing_sl_dist:.2f}")
print(f"Old InpMaxSLPoints Cap: $50.00 (Choked SL to only $50.00 max!)")
mt5.shutdown()
