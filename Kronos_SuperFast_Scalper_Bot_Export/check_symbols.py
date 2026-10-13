import MetaTrader5 as mt5

if mt5.initialize():
    all_symbols = [s.name for s in mt5.symbols_get()]
    gold_syms = [s for s in all_symbols if "XAU" in s or "GOLD" in s]
    btc_syms = [s for s in all_symbols if "BTC" in s]
    print("Gold Symbols:", gold_syms)
    print("BTC Symbols:", btc_syms)
    
    # Check open positions
    positions = mt5.positions_get()
    print("Open Positions:", len(positions) if positions is not None else 0)
    if positions:
        for p in positions:
            print(f"Pos ID: {p.ticket}, Symbol: {p.symbol}, Type: {p.type}, Volume: {p.volume}, Price: {p.price_open}, Profit: {p.profit}")
            
    mt5.shutdown()
