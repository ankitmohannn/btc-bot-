# SmartScalper V2: Reproducible Backtesting & Optimization Guide

## 1. Backtesting Standard Operating Procedure

To ensure institutional validity and prevent curve-fitting, all backtests must follow these standardized protocols:

### Strategy Tester Settings:
- **Symbol**: `BTCUSD` (or `XAUUSD` / `EURUSD`)
- **Period**: `M5` (Primary Setup Timeframe)
- **Model**: **Every tick based on real ticks** (Critical for accurate slippage and sub-second fill simulation)
- **Execution Delay**: **Random Delay (50ms - 150ms)** (Simulates live broker latency)
- **Deposit**: $10,000 USD (or representative trading capital)
- **Leverage**: 1:100 or 1:500

---

## 2. Baseline vs Candidate Comparison Protocol

### Step 1: Establish Reproducible Baseline
1. Open MT5 Strategy Tester (`Ctrl + R`).
2. Select `Kronos_SuperFast_Scalper_EA.mq5` (`BASELINE_STRATEGY`).
3. Set test period: **1 Year** (e.g., 2025.01.01 to 2026.01.01).
4. Run test and record all metrics in the table below.

### Step 2: Run SmartScalper V2 Under Identical Conditions
1. Select `SmartScalper_V2.mq5`.
2. Run test using the exact same date range, symbol, tick data, deposit, and latency.
3. Record metrics and verify performance improvements.

| Performance Metric | Baseline (`Kronos_EA`) | Candidate (`SmartScalper_V2`) | Target Delta |
|---|---|---|---|
| **Total Trades** | - | - | High Quality Selective |
| **Profit Factor** | - | - | > 1.80 |
| **Win Rate (%)** | - | - | > 65% |
| **Max Equity Drawdown (%)** | - | - | < 8.0% |
| **Recovery Factor** | - | - | > 3.5 |
| **Sharpe Ratio** | - | - | > 2.0 |
| **Expectancy ($)** | - | - | Positive |
| **Avg Win / Avg Loss** | - | - | >= 1.50 (1:1.5+ RR) |
| **Max Consecutive Losses** | - | - | <= 3 |

---

## 3. Parameter Optimization: Grouped Walk-Forward Methodology

Do **NOT** optimize all parameters simultaneously. Use disciplined 5-stage optimization:

### Stage 1: Group A & B (Risk & Sizing)
- `InpRiskPercent`: 0.5% - 1.5% (Step 0.25%)
- `InpATRMultiplierSL`: 1.2 - 2.0 (Step 0.2)
- `InpMinimumRR`: 1.5 - 2.5 (Step 0.25)

### Stage 2: Group C (SMC & Market Structure)
- `InpSwingLookback`: 3, 5, 7
- `InpFVGMinSizePoints`: 5 - 20 (Step 5)
- `InpSweepBufferPoints`: 3 - 10 (Step 2)

### Stage 3: Group D (Scoring Weights)
- `InpWeightTrend`: 10.0 - 20.0
- `InpWeightStructure`: 10.0 - 20.0
- `InpWeightLiquidity`: 10.0 - 20.0
- `InpScoreThresholdValid`: 65.0 - 75.0

### Stage 4: Group E (Trade Management & Anti-Overtrading)
- `InpBreakEvenTriggerR`: 0.8R - 1.5R
- `InpTrailingATRMult`: 1.0 - 1.8
- `InpCooldownAfterLoss`: 180s - 600s

---

## 4. Anti-Overfitting & Walk-Forward Validation
1. **In-Sample (IS)**: 70% of dataset (e.g. Month 1 to Month 8).
2. **Out-of-Sample (OOS)**: 30% of dataset (e.g. Month 9 to Month 12).
3. **Rejection Rule**: If Out-of-Sample Profit Factor drops below 1.30 or Drawdown exceeds In-Sample by > 50%, the parameter configuration is rejected.

---

## 5. Running Post-Backtest Monte Carlo Stress Tests
After generating journal data or running tests, execute:
```bash
python ai/bridge/research_evaluator.py
```
This runs 1,000 bootstrap simulations to output 95% and 99% confidence drawdown limits.
