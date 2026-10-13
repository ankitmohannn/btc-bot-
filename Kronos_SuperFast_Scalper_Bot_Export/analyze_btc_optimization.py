import os
import sys
import datetime
import pandas as pd
import numpy as np
import MetaTrader5 as mt5

def main():
    if not mt5.initialize():
        print("MT5 Init Failed")
        return
        
    from_dt = datetime.datetime(2026, 9, 20, 0, 0)
    deals = mt5.history_deals_get(from_dt, datetime.datetime.now())
    
    records = []
    for d in deals:
        if d.entry == 1 and "BTC" in d.symbol:
            records.append({
                "time": datetime.datetime.fromtimestamp(d.time),
                "hour": datetime.datetime.fromtimestamp(d.time).hour,
                "weekday": datetime.datetime.fromtimestamp(d.time).strftime("%A"),
                "profit": d.profit,
                "volume": d.volume,
                "price": d.price,
                "comment": d.comment,
                "is_win": d.profit > 0,
                "is_scratch": abs(d.profit) < 2.0,
                "is_loss": d.profit < 0
            })
            
    df = pd.DataFrame(records)
    if df.empty:
        print("No BTC deals")
        return
        
    print("=" * 70)
    print("           BTC TRADING DEEP QUANTITATIVE DIAGNOSTIC")
    print("=" * 70)
    
    # 1. Scratch Trades Impact (BE stops between -$2.00 and +$2.00)
    scratches = df[df['is_scratch']]
    solid_wins = df[df['profit'] >= 2.0]
    real_losses = df[df['profit'] <= -2.0]
    
    print(f"\n[1] BREAK-EVEN / SCRATCH TRADE DRAG:")
    print(f"  * Total Trades               : {len(df)}")
    print(f"  * Micro-Scratch Trades (<$2) : {len(scratches)} ({len(scratches)/len(df)*100:.1f}%) | Net PnL: ${scratches['profit'].sum():+.2f}")
    print(f"  * Solid Winning Trades (>=+$2): {len(solid_wins)} ({len(solid_wins)/len(df)*100:.1f}%) | Net PnL: ${solid_wins['profit'].sum():+.2f}")
    print(f"  * Real Losses (<=-$2)        : {len(real_losses)} ({len(real_losses)/len(df)*100:.1f}%) | Net PnL: ${real_losses['profit'].sum():+.2f}")

    # 2. Hourly Session Distribution
    print(f"\n[2] HOURLY PERFORMANCE (UTC Hours):")
    hourly = df.groupby('hour')['profit'].agg(['count', 'sum', lambda x: (x > 0).mean() * 100]).reset_index()
    hourly.columns = ['Hour (UTC)', 'Trades', 'Net PnL ($)', 'Win Rate %']
    hourly['Net PnL ($)'] = hourly['Net PnL ($)'].round(2)
    hourly['Win Rate %'] = hourly['Win Rate %'].round(1)
    print(hourly.to_string(index=False))

    # 3. Best vs Worst Hours
    best_hours = hourly[hourly['Net PnL ($)'] > 0]
    worst_hours = hourly[hourly['Net PnL ($)'] < 0]
    print(f"\n  * Profitable Hours Total Net: ${best_hours['Net PnL ($)'].sum():+.2f} across {best_hours['Trades'].sum()} trades")
    print(f"  * Losing Hours Total Net    : ${worst_hours['Net PnL ($)'].sum():+.2f} across {worst_hours['Trades'].sum()} trades")

    # 4. Trade Frequency / Overtrading Check
    df['time_diff'] = df['time'].diff().dt.total_seconds()
    rapid_fire = df[df['time_diff'] < 120] # Trades taken within 2 minutes of prior trade
    print(f"\n[3] OVERTRADING / RAPID-FIRE CHURN (< 2 mins apart):")
    print(f"  * Rapid Churn Trades (<120s): {len(rapid_fire)} ({len(rapid_fire)/len(df)*100:.1f}%)")
    print(f"  * Rapid Churn Net PnL       : ${rapid_fire['profit'].sum():+.2f}")

    # 5. Lot Size vs PnL
    print(f"\n[4] LOT SIZE BRACKET PERFORMANCE:")
    df['lot_bracket'] = pd.cut(df['volume'], bins=[0, 0.20, 0.40, 1.0], labels=['Micro (<0.20L)', 'Mid (0.20-0.40L)', 'Heavy (>0.40L)'])
    lot_summary = df.groupby('lot_bracket', observed=False)['profit'].agg(['count', 'sum', lambda x: (x > 0).mean() * 100]).reset_index()
    lot_summary.columns = ['Lot Bracket', 'Trades', 'Net PnL ($)', 'Win Rate %']
    lot_summary['Net PnL ($)'] = lot_summary['Net PnL ($)'].round(2)
    lot_summary['Win Rate %'] = lot_summary['Win Rate %'].round(1)
    print(lot_summary.to_string(index=False))

    mt5.shutdown()

if __name__ == "__main__":
    main()
