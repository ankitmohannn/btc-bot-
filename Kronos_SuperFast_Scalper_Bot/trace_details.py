import os
import sys
import datetime
import pandas as pd
import MetaTrader5 as mt5

def trace_details():
    if not mt5.initialize():
        return
        
    from_dt = datetime.datetime(2026, 9, 20, 0, 0)
    deals = mt5.history_deals_get(from_dt, datetime.datetime.now())
    
    records = []
    for d in deals:
        if d.entry == 1:
            sym = d.symbol
            if "OIL" in sym: continue
            records.append({
                "time": datetime.datetime.fromtimestamp(d.time),
                "date": datetime.datetime.fromtimestamp(d.time).strftime("%Y-%m-%d"),
                "symbol": "BTCUSD" if "BTC" in sym else ("XAUUSD" if "XAU" in sym or "GOLD" in sym else sym),
                "profit": d.profit,
                "order": d.order,
                "ticket": d.ticket,
                "volume": d.volume,
                "price": d.price,
                "comment": d.comment
            })
            
    df = pd.DataFrame(records)
    
    print("\n--- DAILY PERFORMANCE BREAKDOWN: BTCUSD & XAUUSD ---")
    daily_summary = df.groupby(['date', 'symbol'])['profit'].agg(['count', 'sum', lambda x: (x > 0).sum(), lambda x: (x < 0).sum()]).reset_index()
    daily_summary.columns = ['Date', 'Symbol', 'Trades', 'Net PnL ($)', 'Wins', 'Losses']
    daily_summary['Win Rate %'] = (daily_summary['Wins'] / daily_summary['Trades'] * 100).round(1)
    daily_summary['Net PnL ($)'] = daily_summary['Net PnL ($)'].round(2)
    print(daily_summary.to_string(index=False))

    # Trace Sept 21 specific BTC trades around 16:45 - 17:30
    print("\n--- TRACING SEPT 21 BTC TRADES (Around 16:45 - 17:30 UTC) ---")
    sept21 = df[(df['symbol'] == 'BTCUSD') & (df['date'] == '2026-09-21')]
    for _, r in sept21.iterrows():
        print(f"  * {r['time'].strftime('%Y-%m-%d %H:%M:%S')} | Ticket: {r['ticket']} | Vol: {r['volume']} | PnL: ${r['profit']:+.2f} | Comment: {r['comment']}")
        
    mt5.shutdown()

if __name__ == "__main__":
    trace_details()
