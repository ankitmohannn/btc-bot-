import os
import pandas as pd

appdata = os.getenv("APPDATA")
journal_path = os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files", "smart_scalper_journal.csv")
if os.path.exists(journal_path):
    j = pd.read_csv(journal_path, header=None)
    # Columns: 0: ticket, 1: open_t, 2: close_t, 3: sym, 4: type, ..., 10: pnl, ..., 17: score
    btc = j[j[3].astype(str).str.contains("BTC", na=False)].copy()
    btc[10] = pd.to_numeric(btc[10], errors='coerce')
    btc[17] = pd.to_numeric(btc[17], errors='coerce')
    
    btc['score_bin'] = pd.cut(btc[17], bins=[0, 69.9, 74.9, 79.9, 100], labels=['<70', '70-74.9', '75-79.9', '80+'])
    summary = btc.groupby('score_bin', observed=False)[10].agg(['count', 'sum', lambda x: (x > 0).mean() * 100]).reset_index()
    summary.columns = ['Score Range', 'Trades', 'Net PnL ($)', 'Win Rate %']
    summary['Net PnL ($)'] = summary['Net PnL ($)'].round(2)
    summary['Win Rate %'] = summary['Win Rate %'].round(1)
    print("=== PERFORMANCE BY SIGNAL SCORE ===")
    print(summary.to_string(index=False))
