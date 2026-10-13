"""
High-Performance Vectorized Monte Carlo Simulation Engine for Kronos Scalper
Runs 10,000 simulations per Timeframe & Period in milliseconds using NumPy.
"""

import math
import numpy as np
import pandas as pd

np.random.seed(42)

TIMEFRAMES = {
    "M1": {"label": "1-Minute (High Speed)", "trades_per_day": 8.5, "win_rate": 0.70, "avg_win_r": 1.85, "avg_loss_r": 1.0, "trail_save_rate": 0.12},
    "M5": {"label": "5-Minute (Primary Institutional)", "trades_per_day": 4.2, "win_rate": 0.76, "avg_win_r": 2.20, "avg_loss_r": 1.0, "trail_save_rate": 0.10},
    "M15": {"label": "15-Minute (Swing Scalp)", "trades_per_day": 2.1, "win_rate": 0.79, "avg_win_r": 2.45, "avg_loss_r": 1.0, "trail_save_rate": 0.09},
    "H1": {"label": "1-Hour (Macro Flow)", "trades_per_day": 0.9, "win_rate": 0.82, "avg_win_r": 2.80, "avg_loss_r": 1.0, "trail_save_rate": 0.08}
}

PERIODS_DAYS = {
    "30 Days (1 Month)": 30,
    "90 Days (Quarter)": 90,
    "180 Days (6 Months)": 180,
    "365 Days (1 Year)": 365
}

def run_vectorized_monte_carlo(
    starting_balance: float = 1000.0,
    num_simulations: int = 10000,
    symbol: str = "XAUUSD"
):
    base_r_risk_usd = 4.50 if symbol == "XAUUSD" else 1.20
    results = {}
    
    for tf_key, tf_data in TIMEFRAMES.items():
        results[tf_key] = {}
        for period_label, days in PERIODS_DAYS.items():
            num_trades = int(tf_data["trades_per_day"] * (days * (5/7)))
            num_trades = max(10, num_trades)
            
            # Outcome probabilities
            p_win = tf_data["win_rate"]
            p_be = tf_data["trail_save_rate"]
            p_loss = max(0.0, 1.0 - p_win - p_be)
            probs = np.array([p_win, p_be, p_loss])
            probs = probs / probs.sum()
            
            # 10,000 paths of random outcomes: 0 = win, 1 = BE/trail, 2 = loss
            outcomes = np.random.choice([0, 1, 2], size=(num_simulations, num_trades), p=probs)
            
            # Generate R multiples
            win_r = np.maximum(1.2, np.random.normal(tf_data["avg_win_r"], 0.25, size=(num_simulations, num_trades)))
            be_r = np.random.uniform(0.2, 0.8, size=(num_simulations, num_trades))
            loss_r = -tf_data["avg_loss_r"] * np.ones((num_simulations, num_trades))
            
            r_matrix = np.where(outcomes == 0, win_r, np.where(outcomes == 1, be_r, loss_r))
            
            # Step-by-step equity trajectory with dynamic lot scaling
            equities = np.zeros((num_simulations, num_trades + 1))
            equities[:, 0] = starting_balance
            
            for t in range(num_trades):
                cur_eq = equities[:, t]
                # Lot multiplier = floor(eq / 500), min 1, max 100
                lot_mult = np.clip(np.floor(cur_eq / 500.0), 1, 100)
                trade_pnl = r_matrix[:, t] * base_r_risk_usd * lot_mult
                equities[:, t + 1] = np.maximum(starting_balance * 0.10, cur_eq + trade_pnl)
                
            # Compute final stats across 10,000 simulations
            final_equities = equities[:, -1]
            rois = ((final_equities - starting_balance) / starting_balance) * 100.0
            
            # Peak equity & max drawdown
            cum_max = np.maximum.accumulate(equities, axis=1)
            drawdowns = (cum_max - equities) / cum_max * 100.0
            max_dds = np.max(drawdowns, axis=1)
            
            profit_factor = ((p_win * tf_data["avg_win_r"]) + (p_be * 0.45)) / (p_loss * tf_data["avg_loss_r"])
            ruin_count = np.sum(final_equities <= starting_balance * 0.50)
            
            results[tf_key][period_label] = {
                "trades_count": num_trades,
                "win_rate_actual": (p_win + p_be) * 100.0,
                "median_roi_pct": float(np.percentile(rois, 50)),
                "p05_roi_pct": float(np.percentile(rois, 5)),
                "p25_roi_pct": float(np.percentile(rois, 25)),
                "p75_roi_pct": float(np.percentile(rois, 75)),
                "p95_roi_pct": float(np.percentile(rois, 95)),
                "median_final_equity": float(np.percentile(final_equities, 50)),
                "median_max_dd_pct": float(np.percentile(max_dds, 50)),
                "p95_max_dd_pct": float(np.percentile(max_dds, 95)),
                "p99_max_dd_pct": float(np.percentile(max_dds, 99)),
                "profit_factor": float(profit_factor),
                "risk_of_50pct_dd": float((ruin_count / num_simulations) * 100.0)
            }
            
    return results

if __name__ == "__main__":
    results_gold = run_vectorized_monte_carlo(starting_balance=1000.0, num_simulations=10000, symbol="XAUUSD")
    results_btc = run_vectorized_monte_carlo(starting_balance=1000.0, num_simulations=10000, symbol="BTCUSD")
    
    print("\n" + "="*110)
    print(" MONTE CARLO SIMULATION RESULTS: XAUUSD (GOLD) -- 10,000 RUNS (START: $1,000)")
    print("="*110)
    for tf_key, tf_res in results_gold.items():
        print(f"\n--- {tf_key} TIMEFRAME: {TIMEFRAMES[tf_key]['label']} (Win Rate: {TIMEFRAMES[tf_key]['win_rate']*100:.1f}%, Target RR: 1:{TIMEFRAMES[tf_key]['avg_win_r']:.2f}) ---")
        print(f"{'Period':<20} | {'Trades':<7} | {'Median Net PnL':<15} | {'Median ROI':<11} | {'90% Conf Interval':<22} | {'Median DD':<10} | {'99% Max DD':<10} | {'Profit Factor'}")
        print("-" * 115)
        for period_label, metrics in tf_res.items():
            net_pnl = f"+${metrics['median_final_equity'] - 1000.0:,.2f}"
            conf_interval = f"+{metrics['p05_roi_pct']:,.1f}% to +{metrics['p95_roi_pct']:,.1f}%"
            print(f"{period_label:<20} | {metrics['trades_count']:<7} | {net_pnl:<15} | {metrics['median_roi_pct']:>+8.1f}% | {conf_interval:<22} | {metrics['median_max_dd_pct']:>8.1f}% | {metrics['p99_max_dd_pct']:>8.1f}% | {metrics['profit_factor']:>12.2f}")

    print("\n" + "="*110)
    print(" MONTE CARLO SIMULATION RESULTS: BTCUSD (BITCOIN) -- 10,000 RUNS (START: $1,000)")
    print("="*110)
    for tf_key, tf_res in results_btc.items():
        print(f"\n--- {tf_key} TIMEFRAME: {TIMEFRAMES[tf_key]['label']} (Win Rate: {TIMEFRAMES[tf_key]['win_rate']*100:.1f}%, Target RR: 1:{TIMEFRAMES[tf_key]['avg_win_r']:.2f}) ---")
        print(f"{'Period':<20} | {'Trades':<7} | {'Median Net PnL':<15} | {'Median ROI':<11} | {'90% Conf Interval':<22} | {'Median DD':<10} | {'99% Max DD':<10} | {'Profit Factor'}")
        print("-" * 115)
        for period_label, metrics in tf_res.items():
            net_pnl = f"+${metrics['median_final_equity'] - 1000.0:,.2f}"
            conf_interval = f"+{metrics['p05_roi_pct']:,.1f}% to +{metrics['p95_roi_pct']:,.1f}%"
            print(f"{period_label:<20} | {metrics['trades_count']:<7} | {net_pnl:<15} | {metrics['median_roi_pct']:>+8.1f}% | {conf_interval:<22} | {metrics['median_max_dd_pct']:>8.1f}% | {metrics['p99_max_dd_pct']:>8.1f}% | {metrics['profit_factor']:>12.2f}")
