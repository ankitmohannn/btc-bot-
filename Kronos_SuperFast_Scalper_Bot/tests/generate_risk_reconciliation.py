"""
Generates FORWARD_RISK_RECONCILIATION.csv auditing the lot sizes and risk parameters in the Phase 4 dataset.
"""

import os
import csv

_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
trades_file = os.path.join(_ROOT, "smart_scalper_forward_trades.csv")

if os.path.exists(trades_file):
    with open(trades_file, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        trades = list(reader)
else:
    trades = []

rows = []
initial_equity = 10000.0
running_eq = initial_equity

for t in trades:
    entry = float(t["actual_fill"])
    sl = float(t["actual_sl"])
    lot = float(t["lot_size"])
    sl_dist = abs(entry - sl)
    
    # Audit tick math
    # BTCUSD: 1 contract, tick size 0.01, tick value 0.01 ($1 per $1 move per 1 lot)
    expected_loss = sl_dist * lot * 1.0
    risk_pct = (expected_loss / running_eq) * 100.0 if running_eq > 0 else 0.0
    
    pnl = float(t["pnl_net_usd"])
    
    rows.append({
        "trade_id": t["trade_id"],
        "timestamp": t["timestamp"],
        "equity_before": round(running_eq, 2),
        "lot_size": lot,
        "entry_price": entry,
        "sl_price": sl,
        "sl_distance_usd": round(sl_dist, 2),
        "expected_loss_at_sl_usd": round(expected_loss, 2),
        "risk_pct_of_equity": round(risk_pct, 2),
        "actual_pnl_usd": pnl,
        "lot_variance_flag": "FIXED_LOT_FLAG" if lot == 0.40 else "DYNAMIC"
    })
    running_eq += pnl

out_file = os.path.join(_ROOT, "FORWARD_RISK_RECONCILIATION.csv")
if rows:
    with open(out_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(f"[RECON] Generated FORWARD_RISK_RECONCILIATION.csv ({len(rows)} records)")
