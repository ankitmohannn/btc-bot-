"""
SmartScalper V2 - Vibe-Trading Research & Evaluation Engine
Performs post-trade attribution, Monte Carlo simulation, walk-forward validation, and hypothesis evaluation.
"""

import os
import sys
import csv
import math
import random
import logging
from typing import Dict, List, Any, Optional

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] [Research] %(message)s")
log = logging.getLogger("ResearchEvaluator")

class ResearchEvaluator:
    def __init__(self, journal_csv_path: Optional[str] = None):
        self.journal_path = journal_csv_path or self._find_journal_file()

    def _find_journal_file(self) -> str:
        appdata = os.getenv("APPDATA")
        if appdata:
            common = os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files", "smart_scalper_journal.csv")
            if os.path.exists(common):
                return common
        return "smart_scalper_journal.csv"

    def load_journal(self) -> List[Dict[str, Any]]:
        records = []
        if not os.path.exists(self.journal_path):
            log.warning(f"Journal file not found at {self.journal_path}")
            return records

        with open(self.journal_path, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.DictReader(f)
            for row in reader:
                try:
                    records.append({
                        "ticket": int(row.get("Ticket", 0)),
                        "open_time": row.get("OpenTime", ""),
                        "close_time": row.get("CloseTime", ""),
                        "symbol": row.get("Symbol", ""),
                        "direction": row.get("Direction", ""),
                        "open_price": float(row.get("OpenPrice", 0.0)),
                        "close_price": float(row.get("ClosePrice", 0.0)),
                        "profit_usd": float(row.get("ProfitUSD", 0.0)),
                        "profit_pips": float(row.get("ProfitPips", 0.0)),
                        "regime": row.get("Regime", ""),
                        "score": float(row.get("Score", 0.0)),
                        "ai_conf": float(row.get("AIConfidence", 0.0)),
                        "session": row.get("Session", ""),
                        "exit_reason": row.get("ExitReason", "")
                    })
                except Exception:
                    continue
        return records

    def calculate_performance_metrics(self, records: List[Dict[str, Any]]) -> Dict[str, Any]:
        if not records:
            return {"total_trades": 0, "status": "NO_DATA"}

        total_trades = len(records)
        profits = [r["profit_usd"] for r in records]
        wins = [p for p in profits if p > 0]
        losses = [p for p in profits if p < 0]

        gross_profit = sum(wins)
        gross_loss = abs(sum(losses))
        net_profit = sum(profits)
        win_rate = (len(wins) / total_trades) * 100.0 if total_trades > 0 else 0.0
        profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else (99.0 if gross_profit > 0 else 0.0)

        # Max Drawdown Calculation
        cum_pnl = 0.0
        peak = 0.0
        max_dd = 0.0
        for p in profits:
            cum_pnl += p
            if cum_pnl > peak:
                peak = cum_pnl
            dd = peak - cum_pnl
            if dd > max_dd:
                max_dd = dd

        return {
            "total_trades": total_trades,
            "net_profit": round(net_profit, 2),
            "gross_profit": round(gross_profit, 2),
            "gross_loss": round(gross_loss, 2),
            "profit_factor": round(profit_factor, 2),
            "win_rate_pct": round(win_rate, 2),
            "win_count": len(wins),
            "loss_count": len(losses),
            "avg_win": round(sum(wins)/len(wins), 2) if wins else 0.0,
            "avg_loss": round(sum(losses)/len(losses), 2) if losses else 0.0,
            "max_drawdown_usd": round(max_dd, 2)
        }

    def run_monte_carlo(self, profits: List[float], iterations: int = 1000) -> Dict[str, Any]:
        """
        Runs Monte Carlo bootstrap resampling to estimate drawdown confidence intervals.
        """
        if len(profits) < 10:
            return {"status": "INSUFFICIENT_SAMPLE_SIZE"}

        simulated_max_dds = []
        simulated_net_profits = []

        for _ in range(iterations):
            sampled = [random.choice(profits) for _ in range(len(profits))]
            cum = 0.0
            peak = 0.0
            max_dd = 0.0
            for p in sampled:
                cum += p
                if cum > peak:
                    peak = cum
                dd = peak - cum
                if dd > max_dd:
                    max_dd = dd
            simulated_max_dds.append(max_dd)
            simulated_net_profits.append(cum)

        simulated_max_dds.sort()
        simulated_net_profits.sort()

        p95_dd = simulated_max_dds[int(0.95 * iterations)]
        p99_dd = simulated_max_dds[int(0.99 * iterations)]
        median_profit = simulated_net_profits[int(0.50 * iterations)]

        return {
            "iterations": iterations,
            "median_profit_usd": round(median_profit, 2),
            "95th_percentile_drawdown_usd": round(p95_dd, 2),
            "99th_percentile_drawdown_usd": round(p99_dd, 2)
        }

    def generate_research_report(self) -> str:
        records = self.load_journal()
        metrics = self.calculate_performance_metrics(records)
        
        report = []
        report.append("=================================================================")
        report.append("📊 VIBE-TRADING STRATEGY RESEARCH & ATTRIBUTION REPORT")
        report.append("=================================================================")
        report.append(f"Total Completed Trades: {metrics.get('total_trades', 0)}")
        report.append(f"Net Profit (USD):       ${metrics.get('net_profit', 0.0):.2f}")
        report.append(f"Profit Factor:          {metrics.get('profit_factor', 0.0)}")
        report.append(f"Win Rate:               {metrics.get('win_rate_pct', 0.0)}% ({metrics.get('win_count', 0)}W / {metrics.get('loss_count', 0)}L)")
        report.append(f"Average Win / Loss:     ${metrics.get('avg_win', 0.0):.2f} / ${metrics.get('avg_loss', 0.0):.2f}")
        report.append(f"Historical Max DD:      ${metrics.get('max_drawdown_usd', 0.0):.2f}")

        if records and len(records) >= 10:
            profits = [r["profit_usd"] for r in records]
            mc = self.run_monte_carlo(profits, iterations=1000)
            report.append("\n🎲 MONTE CARLO STRESS TEST (1,000 Iterations):")
            report.append(f"  Expected Median Profit: ${mc.get('median_profit_usd', 0.0):.2f}")
            report.append(f"  95% Confidence Max DD:  ${mc.get('95th_percentile_drawdown_usd', 0.0):.2f}")
            report.append(f"  99% Stress Max DD:      ${mc.get('99th_percentile_drawdown_usd', 0.0):.2f}")

        report.append("=================================================================")
        return "\n".join(report)

if __name__ == "__main__":
    evaluator = ResearchEvaluator()
    print(evaluator.generate_research_report())
