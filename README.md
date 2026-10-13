# ⚡ Kronos Institutional Scalper & VIP Signal Engine

An institutional-grade algorithmic trading system and multi-timeframe Market Structure / SMC scanner engineered for MetaTrader 5 (MT5).

---

## 🌟 Key Architecture & Capabilities

### 1. SmartScalper V2 (MQL5 Expert Advisor)
- **Timeframe**: Optimized for M5 execution on high-volatility institutional pairs (`BTCUSD`, `XAUUSD`).
- **Core Signal Synthesis**:
  - **Trend Ribbon Alignment**: Multi-EMA dynamic slope filtering (EMA 9, 20, 50, 200).
  - **Smart Money Concepts (SMC)**: Real-time non-repainting Break of Structure (BOS), Change of Character (CHoCH), and Liquidity Sweeps (BSL/SSL).
  - **Institutional Imbalance**: Fair Value Gap (FVG) and Order Block detection with mitigation tracking.
  - **Dynamic Volatility Shield**: Parkinson Volatility estimation and tail-risk scaling.
- **Risk & Execution Plan**:
  - **SL-Free Floating Breathing Room**: Trades run with dynamic market structure adaptation.
  - **Signal Reversal Auto-Cut**: Liquidates opposing positions immediately upon confirmed opposite reversal signals.
  - **Institutional Max Lot Ceiling**: Capped strictly per trade (default 0.40 lots max).
  - **Take Profit**: Multi-tier dynamic TP with trailing runner capabilities.

---

### 2. Kronos VIP Institutional Signal Scanner (Python Engine)
- **Continuous Multi-Asset Confluence Scanner**:
  - Runs in real-time connected directly to MetaTrader 5 terminal via Python IPC.
  - Evaluates M1, M5, M15, and H1 confluence scores (0–100%).
  - Multi-Timeframe SMC Dealing Range (Premium vs Discount Zone analysis).
- **VIP Telegram Alerts**:
  - Automatic dispatch of rich formatted signal cards with institutional entry reasoning.
  - Full TP1, Runner TP, and Risk Plan breakdown.

---

## 📁 Repository Structure

```
Kronos_AF/
├── Kronos_SuperFast_Scalper_Bot/          # Core Bot Source Code
│   ├── SmartScalper_V2.mq5                # Primary Institutional MQL5 EA
│   ├── Kronos_SuperFast_Scalper.mq5       # Ultra-Fast Scalper EA Variant
│   ├── kronos_vip_signal_scanner.py       # 24/7 Python VIP Signal Generator & Telegram Broadcaster
│   ├── scan_mtf.py                        # Multi-Timeframe SMC & RSI Scanner
│   ├── signal_match_validator.py          # Backtest vs Forward Signal Match Engine
│   ├── run_vip_signal_scanner.bat         # Automated one-click scanner launcher
│   └── Include/                           # Modular Architecture Includes
│       └── SmartScalper/
│           ├── SmartScalper_TradeManager.mqh
│           ├── SmartScalper_Filters.mqh
│           ├── SmartScalper_Scoring.mqh
│           ├── SmartScalper_SMC.mqh
│           ├── SmartScalper_VolatilityShield.mqh
│           ├── SmartScalper_Telegram.mqh
│           ├── SmartScalper_HUD.mqh
│           └── ...
├── Kronos_SuperFast_Scalper_Bot_Export/   # Compiled Deployment Package
│   ├── Experts/                           # Ready-to-use compiled .ex5 files
│   └── Include/                           # Pre-packaged include headers
├── Kronos_SuperFast_Scalper_Bot_Release.zip # Full Portable Release Archive
└── README.md
```

---

## 🚀 Quick Start Guide

### 1. MT5 EA Setup
1. Copy the contents of `Kronos_SuperFast_Scalper_Bot/Include/` into your MetaTrader 5 `MQL5/Include/` directory.
2. Compile `SmartScalper_V2.mq5` using MetaEditor or load the pre-compiled `.ex5` from `Kronos_SuperFast_Scalper_Bot_Export/Experts/`.
3. Attach to a **BTCUSD** or **XAUUSD** chart on the **M5** timeframe.
4. Ensure **Algo Trading** is enabled in MT5.

### 2. VIP Python Scanner Setup
1. Install requirements:
   ```bash
   pip install MetaTrader5 pandas numpy
   ```
2. Launch the scanner:
   ```bash
   run_vip_signal_scanner.bat
   ```

---

## 🛡️ License & Copyright
Copyright © 2026 Institutional AI Trading Systems. All rights reserved.
