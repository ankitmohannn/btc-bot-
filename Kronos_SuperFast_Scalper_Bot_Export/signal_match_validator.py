"""
SmartScalper V2 - Backtest vs Forward Signal Match Validator
Compares theoretical/backtest signals against live forward EA shadow signals and executed trades.
Measures:
  - Signal match %
  - Direction match %
  - Score delta (mean, max)
  - SL delta (pts)
  - TP delta (pts)
  - Lot size delta
Target: >= 95% deterministic agreement.
"""

import os
import sys
import math
from typing import Dict, List, Any

def validate_signal_matches(backtest_signals: List[Dict[str, Any]], forward_signals: List[Dict[str, Any]]) -> Dict[str, Any]:
    if not backtest_signals or not forward_signals:
        return {
            "total_comparisons": 0,
            "signal_match_pct": 0.0,
            "direction_match_pct": 0.0,
            "mean_score_diff": 0.0,
            "max_score_diff": 0.0,
            "mean_sl_diff_pts": 0.0,
            "mean_tp_diff_pts": 0.0,
            "mean_lot_diff": 0.0,
            "status": "NO_DATA"
        }

    n = min(len(backtest_signals), len(forward_signals))
    exact_signal_matches = 0
    direction_matches = 0
    score_diffs = []
    sl_diffs = []
    tp_diffs = []
    lot_diffs = []

    for i in range(n):
        bt = backtest_signals[i]
        fw = forward_signals[i]

        bt_dir = bt.get("direction")
        fw_dir = fw.get("direction")
        dir_match = (bt_dir == fw_dir)
        if dir_match:
            direction_matches += 1

        bt_score = bt.get("score") if bt.get("score") is not None else bt.get("total_score", 0.0)
        fw_score = fw.get("score") if fw.get("score") is not None else fw.get("total_score", 0.0)
        s_diff = abs(bt_score - fw_score)
        score_diffs.append(s_diff)

        bt_sl = bt.get("sl") if bt.get("sl") is not None else bt.get("req_sl", 0.0)
        fw_sl = fw.get("sl") if fw.get("sl") is not None else fw.get("req_sl", 0.0)
        sl_diff = abs(bt_sl - fw_sl)
        sl_diffs.append(sl_diff)

        bt_tp = bt.get("tp") if bt.get("tp") is not None else bt.get("req_tp", 0.0)
        fw_tp = fw.get("tp") if fw.get("tp") is not None else fw.get("req_tp", 0.0)
        tp_diff = abs(bt_tp - fw_tp)
        tp_diffs.append(tp_diff)

        bt_lot = bt.get("lot") if bt.get("lot") is not None else bt.get("lot_size", 0.0)
        fw_lot = fw.get("lot") if fw.get("lot") is not None else fw.get("lot_size", 0.0)
        lot_diff = abs(bt_lot - fw_lot)
        lot_diffs.append(lot_diff)

        # Exact match requires same direction, score diff < 0.01 pt, and exact lot size
        if dir_match and s_diff < 0.01 and lot_diff < 0.0001:
            exact_signal_matches += 1

    signal_match_pct = (exact_signal_matches / n) * 100.0 if n > 0 else 0.0
    direction_match_pct = (direction_matches / n) * 100.0 if n > 0 else 0.0
    mean_s_diff = sum(score_diffs) / len(score_diffs) if score_diffs else 0.0
    max_s_diff = max(score_diffs) if score_diffs else 0.0
    mean_sl_diff = sum(sl_diffs) / len(sl_diffs) if sl_diffs else 0.0
    mean_tp_diff = sum(tp_diffs) / len(tp_diffs) if tp_diffs else 0.0
    mean_lot_diff = sum(lot_diffs) / len(lot_diffs) if lot_diffs else 0.0

    target_achieved = (signal_match_pct >= 95.0)

    return {
        "total_comparisons": n,
        "exact_matches": exact_signal_matches,
        "signal_match_pct": round(signal_match_pct, 2),
        "direction_match_pct": round(direction_match_pct, 2),
        "mean_score_diff": round(mean_s_diff, 3),
        "max_score_diff": round(max_s_diff, 3),
        "mean_sl_diff_pts": round(mean_sl_diff, 2),
        "mean_tp_diff_pts": round(mean_tp_diff, 2),
        "mean_lot_diff": round(mean_lot_diff, 4),
        "target_threshold_pct": 95.0,
        "status": "PASS" if target_achieved else "FAIL"
    }

if __name__ == "__main__":
    print("[INIT] Signal Match Validator ready.")
