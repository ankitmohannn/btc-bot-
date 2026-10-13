import os
import sys
import json
import datetime
import pandas as pd
import numpy as np
import MetaTrader5 as mt5

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

def main():
    if not mt5.initialize():
        print(f"MT5 Init Error: {mt5.last_error()}")
        return

    term = mt5.terminal_info()
    acc = mt5.account_info()
    print("=" * 80)
    print(f"          KRONOS TRADE & LOG AUDIT REPORT: GOLD (XAUUSD) & BTC (BTCUSD)")
    print(f"               Account: {acc.login} ({acc.server}) | Balance: ${acc.balance:.2f} | Equity: ${acc.equity:.2f}")
    print("=" * 80)

    # 1. Open Positions
    open_positions = mt5.positions_get()
    print("\n[1] ACTIVE OPEN POSITIONS:")
    if open_positions:
        for p in open_positions:
            if "OIL" in p.symbol: continue
            p_type = "BUY" if p.type == 0 else "SELL"
            print(f"  * #{p.ticket} | {p.symbol} | {p_type} {p.volume}L @ {p.price_open:.2f} -> Current: {p.price_current:.2f} | SL: {p.sl:.2f} | TP: {p.tp:.2f} | PnL: ${p.profit:+.2f} | Comment: {p.comment}")
    else:
        print("  * No open positions currently active.")

    # 2. History Deals Analysis
    from_dt = datetime.datetime(2026, 9, 20, 0, 0)
    to_dt = datetime.datetime.now()
    deals = mt5.history_deals_get(from_dt, to_dt)
    
    if deals:
        df_deals = []
        for d in deals:
            if d.entry == 1: # Out (Closed trade)
                sym = d.symbol
                if "OIL" in sym: continue
                if "BTC" in sym or "XAU" in sym or "GOLD" in sym:
                    df_deals.append({
                        "ticket": d.ticket,
                        "order": d.order,
                        "time": datetime.datetime.fromtimestamp(d.time),
                        "symbol": "BTCUSD" if "BTC" in sym else "XAUUSD",
                        "type": "BUY" if d.type == 1 else "SELL", # Opposite of closing deal type, or closing deal type
                        "volume": d.volume,
                        "price": d.price,
                        "profit": d.profit,
                        "comment": d.comment,
                        "magic": d.magic
                    })
        
        df = pd.DataFrame(df_deals)
        if not df.empty:
            print(f"\n[2] HISTORICAL TRADE PERFORMANCE SUMMARY (Sept 20 - Sept 30):")
            for sym in ["BTCUSD", "XAUUSD"]:
                sym_df = df[df['symbol'] == sym]
                if sym_df.empty:
                    print(f"\n  --- {sym} ---")
                    print(f"  * No closed trades found.")
                    continue
                    
                total_trades = len(sym_df)
                wins = sym_df[sym_df['profit'] > 0]
                losses = sym_df[sym_df['profit'] < 0]
                scratch = sym_df[sym_df['profit'] == 0]
                
                total_pnl = sym_df['profit'].sum()
                gross_profit = wins['profit'].sum() if not wins.empty else 0.0
                gross_loss = abs(losses['profit'].sum()) if not losses.empty else 0.0
                pf = (gross_profit / gross_loss) if gross_loss > 0 else (999.0 if gross_profit > 0 else 0.0)
                win_rate = (len(wins) / total_trades) * 100.0
                
                print(f"\n  📊 --- {sym} SUMMARY ---")
                print(f"  * Total Trades Executed : {total_trades}")
                print(f"  * Wins / Losses / Flat  : {len(wins)} W / {len(losses)} L / {len(scratch)} Flat")
                print(f"  * Win Rate              : {win_rate:.1f}%")
                print(f"  * Total Net Realized PnL: ${total_pnl:+.2f}")
                print(f"  * Gross Profit          : ${gross_profit:.2f}")
                print(f"  * Gross Loss            : ${gross_loss:.2f}")
                print(f"  * Profit Factor (PF)    : {pf:.2f}")
                if not wins.empty:
                    print(f"  * Max Win / Avg Win     : ${wins['profit'].max():+.2f} / ${wins['profit'].mean():+.2f}")
                if not losses.empty:
                    print(f"  * Max Loss / Avg Loss   : ${losses['profit'].min():+.2f} / ${losses['profit'].mean():+.2f}")
                
                # Breakdown by exit type comment
                tp_exits = sym_df[sym_df['comment'].str.contains('tp', case=False, na=False)]
                sl_exits = sym_df[sym_df['comment'].str.contains('sl', case=False, na=False)]
                other_exits = sym_df[~sym_df['comment'].str.contains('tp|sl', case=False, na=False)]
                print(f"  * Exit Trigger Types    : TP Hits: {len(tp_exits)} | SL/BE Hits: {len(sl_exits)} | Manual/Other: {len(other_exits)}")

            print(f"\n[3] LAST 10 CLOSED TRADES:")
            for _, r in df.tail(10).iterrows():
                print(f"  * {r['time'].strftime('%Y-%m-%d %H:%M:%S')} | {r['symbol']:<6} | Vol: {r['volume']:.2f}L | Net PnL: ${r['profit']:+7.2f} | Comment: {r['comment']}")
        else:
            print("\n  * No closed deals found for BTCUSD or XAUUSD.")

    # 3. Check Journal CSV if present
    appdata = os.getenv("APPDATA")
    journal_path = os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files", "smart_scalper_journal.csv")
    if os.path.exists(journal_path):
        try:
            print("\n[4] ON-CHART JOURNAL AUDIT (smart_scalper_journal.csv):")
            j_df = pd.read_csv(journal_path, header=None)
            print(f"  * Total Journaled Events: {len(j_df)}")
            # Filter for BTC / XAU
            btc_j = j_df[j_df[3].astype(str).str.contains("BTC", na=False)]
            xau_j = j_df[j_df[3].astype(str).str.contains("XAU|GOLD", na=False)]
            print(f"  * Journaled BTC Records : {len(btc_j)}")
            print(f"  * Journaled Gold Records: {len(xau_j)}")
            if not btc_j.empty:
                last_btc = btc_j.iloc[-1]
                print(f"  * Last BTC Journal Trade: Time: {last_btc[2]} | Type: {last_btc[4]} | PnL: ${float(last_btc[10]):+.2f} | Exit: {last_btc[23]}")
            if not xau_j.empty:
                last_xau = xau_j.iloc[-1]
                print(f"  * Last Gold Journal Trade: Time: {last_xau[2]} | Type: {last_xau[4]} | PnL: ${float(last_xau[10]):+.2f} | Exit: {last_xau[23]}")
        except Exception as e:
            print(f"  * Journal parse note: {e}")

    mt5.shutdown()
    print("\n" + "=" * 80)

if __name__ == "__main__":
    main()
