import os
import sys
import json
import datetime
import pandas as pd
import numpy as np
import MetaTrader5 as mt5

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def analyze_symbol(sym, tf_enum=mt5.TIMEFRAME_M5, tf_name="M5"):
    print(f"\n==================================================")
    print(f"       LIVE MARKET SCANNER: {sym} ({tf_name})")
    print(f"==================================================")
    
    # 1. Fetch live candles
    rates = mt5.copy_rates_from_pos(sym, tf_enum, 0, 100)
    if rates is None or len(rates) < 50:
        print(f"Error: Could not get rates for {sym}")
        return
        
    df = pd.DataFrame(rates)
    df['time'] = pd.to_datetime(df['time'], unit='s')
    
    # Indicators
    df['ema9'] = df['close'].ewm(span=9, adjust=False).mean()
    df['ema20'] = df['close'].ewm(span=20, adjust=False).mean()
    df['ema50'] = df['close'].ewm(span=50, adjust=False).mean()
    df['ema200'] = df['close'].ewm(span=200, adjust=False).mean()
    
    # RSI (14)
    delta = df['close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    rs = gain / (loss + 1e-9)
    df['rsi'] = 100 - (100 / (1 + rs))
    
    cur_close = df['close'].iloc[-1]
    cur_ema9 = df['ema9'].iloc[-1]
    cur_ema20 = df['ema20'].iloc[-1]
    cur_ema50 = df['ema50'].iloc[-1]
    cur_rsi = df['rsi'].iloc[-1]
    
    # Swing High / Low (Lookback 5)
    recent_high = df['high'].iloc[-20:].max()
    recent_low = df['low'].iloc[-20:].min()
    dealing_range = recent_high - recent_low
    equilibrium = (recent_high + recent_low) / 2.0
    is_discount = cur_close < equilibrium
    is_premium = cur_close > equilibrium
    
    tick = mt5.symbol_info_tick(sym)
    sym_info = mt5.symbol_info(sym)
    spread_pts = (tick.ask - tick.bid) / sym_info.point if (tick and sym_info) else 0
    
    print(f"Current Price   : {cur_close}")
    print(f"Spread Points   : {spread_pts:.1f} pts (Max Allowed: 60 pts)")
    print(f"EMA Alignment   : EMA9={cur_ema9:.2f}, EMA20={cur_ema20:.2f}, EMA50={cur_ema50:.2f}")
    print(f"RSI (14)        : {cur_rsi:.2f}")
    print(f"Dealing Range   : Low={recent_low:.2f} | Eq={equilibrium:.2f} | High={recent_high:.2f}")
    print(f"Zone            : {'DISCOUNT (Favors BUY)' if is_discount else 'PREMIUM (Favors SELL)'}")
    
    # Evaluate Scoring Model
    # BUY scoring
    buy_trend = (6.0 if cur_ema9 > cur_ema20 else 0) + (5.25 if cur_ema20 > cur_ema50 else 0)
    buy_mom = 3.5 if (45 <= cur_rsi <= 68) else 0
    buy_liq = (5.25 if is_discount else 0)
    buy_spread = 5.0 if spread_pts < 30 else (3.0 if spread_pts <= 60 else 0)
    buy_sess = 5.0 # NY / London
    total_buy = buy_trend + buy_mom + buy_liq + buy_spread + buy_sess
    
    # SELL scoring
    sell_trend = (6.0 if cur_ema9 < cur_ema20 else 0) + (5.25 if cur_ema20 < cur_ema50 else 0)
    sell_mom = 3.5 if (32 <= cur_rsi <= 55) else 0
    sell_liq = (5.25 if is_premium else 0)
    sell_spread = 5.0 if spread_pts < 30 else (3.0 if spread_pts <= 60 else 0)
    sell_sess = 5.0
    total_sell = sell_trend + sell_mom + sell_liq + sell_spread + sell_sess
    
    print(f"\n--- SCORING BREAKDOWN ---")
    print(f"BUY  Score: {total_buy:.1f}/100 (Threshold needed: >= 70.0)")
    print(f"SELL Score: {total_sell:.1f}/100 (Threshold needed: >= 70.0)")
    
    if total_buy < 70.0 and total_sell < 70.0:
        print(f"Result: ⏸️ HOLD - No clear institutional confluence (Score below 70 threshold).")
    elif total_buy >= 70.0:
        print(f"Result: 🟢 VALID BUY SIGNAL")
    elif total_sell >= 70.0:
        print(f"Result: 🔴 VALID SELL SIGNAL")

def main():
    if not mt5.initialize():
        print("MT5 init failed")
        return
    analyze_symbol("XAUUSD", mt5.TIMEFRAME_M5, "M5")
    analyze_symbol("BTCUSD", mt5.TIMEFRAME_M5, "M5")
    mt5.shutdown()

if __name__ == "__main__":
    main()
