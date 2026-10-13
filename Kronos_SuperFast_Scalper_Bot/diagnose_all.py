import os
import sys
import json
import datetime
import MetaTrader5 as mt5

def main():
    print("=" * 70)
    print("      KRONOS SCALPER BOT & MT5 INTEGRATION DIAGNOSTIC AUDIT")
    print("=" * 70)
    
    # 1. MT5 Connectivity
    if not mt5.initialize():
        print(f"[FAIL] MT5 Initialize Error: {mt5.last_error()}")
        return
        
    term = mt5.terminal_info()
    acc = mt5.account_info()
    
    print("\n[1] MT5 TERMINAL & BROKER STATUS:")
    print(f"  - Terminal Name       : {term.name}")
    print(f"  - Terminal Connected  : {'YES' if term.connected else 'NO'}")
    print(f"  - Terminal Trade Auto : {'YES' if term.trade_allowed else 'NO'}")
    print(f"  - Account Login       : {acc.login} ({acc.name})")
    print(f"  - Server              : {acc.server}")
    print(f"  - Balance / Equity    : ${acc.balance:.2f} / ${acc.equity:.2f}")
    print(f"  - Margin Free / Lev   : ${acc.margin_free:.2f} / 1:{acc.leverage}")
    print(f"  - Algo Trading Flag   : {'ENABLED' if acc.trade_expert else 'DISABLED'}")
    
    # 2. Market Rates Check (XAUUSD & BTCUSD)
    print("\n[2] LIVE SYMBOLS & TICK HEALTH:")
    for sym in ["XAUUSD", "BTCUSD"]:
        selected = mt5.symbol_select(sym, True)
        info = mt5.symbol_info(sym)
        tick = mt5.symbol_info_tick(sym)
        if info and tick:
            spread = (tick.ask - tick.bid) / info.point
            print(f"  - {sym:<6} -> Bid: {tick.bid:<10.3f} | Ask: {tick.ask:<10.3f} | Spread: {spread:5.1f} pts | Selected: {selected}")
        else:
            print(f"  - {sym:<6} -> Could not fetch tick info!")
            
    # 3. Active Open Positions & Pending Orders
    print("\n[3] CURRENT OPEN POSITIONS & ORDERS:")
    positions = mt5.positions_get()
    if positions:
        print(f"  - Open Positions ({len(positions)}):")
        for p in positions:
            p_type = "BUY" if p.type == 0 else "SELL"
            print(f"    * #{p.ticket} | {p.symbol} | {p_type} {p.volume} lots @ {p.price_open} | SL: {p.sl} | TP: {p.tp} | Profit: ${p.profit:.2f} | Magic: {p.magic}")
    else:
        print("  - No open positions currently active.")
        
    orders = mt5.orders_get()
    if orders:
        print(f"  - Pending Orders ({len(orders)}):")
        for o in orders:
            print(f"    * #{o.ticket} | {o.symbol} | Type: {o.type} | Volume: {o.volume} | Price: {o.price_open}")
    else:
        print("  - No pending orders.")

    # 4. Recent Trade Deals
    print("\n[4] RECENT TRADE HISTORY (Last 48 Hours):")
    from_dt = datetime.datetime.now() - datetime.timedelta(days=2)
    deals = mt5.history_deals_get(from_dt, datetime.datetime.now())
    if deals:
        print(f"  - Total Closed Deals: {len(deals)}")
        recent_deals = [d for d in deals if d.entry == 1] # Exit deals
        total_pnl = sum(d.profit for d in recent_deals)
        print(f"  - Total Realized PnL (Closed trades): ${total_pnl:.2f}")
        print("  - Last 5 Closed Trades:")
        for d in recent_deals[-5:]:
            d_time = datetime.datetime.fromtimestamp(d.time)
            print(f"    * {d_time.strftime('%Y-%m-%d %H:%M:%S')} | {d.symbol} | Vol: {d.volume} | Profit: ${d.profit:+.2f} | Comment: {d.comment}")
    else:
        print("  - No deals in history for the last 48 hours.")
        
    # 5. Live IPC / MQL5 Bridge File Checks
    print("\n[5] MQL5 <-> PYTHON IPC BRIDGE TELEMETRY:")
    appdata = os.getenv("APPDATA")
    common_feat = os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files", "smart_scalper_features.json")
    common_sig = os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files", "smart_scalper_signal.json")
    
    if os.path.exists(common_feat):
        mtime = os.path.getmtime(common_feat)
        age = time.time() - mtime
        with open(common_feat, "r") as f:
            feat_data = json.load(f)
        print(f"  - smart_scalper_features.json: ACTIVE (Last updated {age:.1f}s ago)")
        print(f"    * Symbol: {feat_data.get('symbol')} | Close: {feat_data.get('close')} | RSI: {feat_data.get('rsi')} | ADX: {feat_data.get('adx')} | ATR: {feat_data.get('atr')}")
    else:
        print("  - smart_scalper_features.json: NOT FOUND in Common/Files")
        
    if os.path.exists(common_sig):
        mtime = os.path.getmtime(common_sig)
        age = time.time() - mtime
        with open(common_sig, "r") as f:
            sig_data = json.load(f)
        print(f"  - smart_scalper_signal.json  : PRESENT (Last updated {age:.1f}s ago)")
        print(f"    * Direction: {sig_data.get('direction')} | Confidence: {sig_data.get('confidence')}% | Risk Score: {sig_data.get('risk_score')}")
    else:
        print("  - smart_scalper_signal.json  : NOT FOUND in Common/Files")

    mt5.shutdown()
    print("\n" + "=" * 70)
    print("                    AUDIT SUMMARY: BOT STATUS")
    print("=" * 70)

if __name__ == "__main__":
    import time
    main()
