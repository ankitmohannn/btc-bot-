import MetaTrader5 as mt5

if not mt5.initialize():
    print("MT5 initialization failed:", mt5.last_error())
else:
    term = mt5.terminal_info()
    acc = mt5.account_info()
    print("Terminal:", term.name if term else "Unknown")
    print("Trade Allowed on Terminal:", term.trade_allowed if term else "Unknown")
    print("Connected:", term.connected if term else "Unknown")
    if acc:
        print(f"Account: {acc.login} | Server: {acc.server} | Balance: {acc.balance} | Equity: {acc.equity} | Currency: {acc.currency}")
        print("Algo Trading Allowed on Account:", acc.trade_expert)
    else:
        print("No account info found.")
    
    symbols = [s.name for s in mt5.symbols_get() if "BTC" in s.name or "XAU" in s.name or "GOLD" in s.name]
    print("Matching Symbols in MT5:", symbols[:10])
    mt5.shutdown()
