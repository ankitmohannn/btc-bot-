# Kronos SuperFast Scalper Bot — Complete A to Z File Catalog & Architecture

This document provides a comprehensive A to Z directory of every file in this system, categorized by layer and functional responsibility.

---

## 📁 1. Desktop Deployment Locations
- **Extracted Folder**: `C:\Users\aakash\Desktop\Kronos_SuperFast_Scalper_Bot_A_to_Z\`
- **Compressed Archive**: `C:\Users\aakash\Desktop\Kronos_SuperFast_Scalper_Bot_A_to_Z.zip`
- **Main Development Workspace**: `C:\Users\aakash\Desktop\Kronos_SuperFast_Scalper_Bot\`

---

## 📑 2. A to Z File Inventory

### 🟢 Launch Scripts & Batch Automations (`.bat`)
1. **`run_247_watchdog.bat`**: Runs the 24/7 self-healing supervisor watchdog that restarts MT5/Bridge on failure.
2. **`run_ai_assistant.bat`**: Launches the OpenAI streaming market intelligence and trade commentary engine.
3. **`run_ai_bridge.bat`** *(under `ai/bridge/`)*: Launches the AI vibe-trading bridge adapter.
4. **`run_btc_bridge.bat`**: Launches dedicated Python ZeroMQ / IPC bridge for BTCUSD scalping.
5. **`run_btc_xau_bridge.bat`**: Launches multi-symbol bridging engine servicing both BTCUSD and XAUUSD simultaneously.
6. **`run_dashboard.bat`**: Starts the local HTTP telemetry web server for the HUD and trade metrics dashboard.
7. **`run_super_fast_scalper.bat`**: Main one-click runner for the full high-frequency scalper pipeline.
8. **`run_xau_bridge.bat`**: Launches dedicated Python bridge for Gold (XAUUSD).

---

### 🧠 AI & Bridge Modules (`ai/` & `ai/bridge/`)
9. **`ai/openai_assistant.py`**: Integration with OpenAI API for natural-language trade sentiment and trade plan commentary.
10. **`ai/bridge/research_evaluator.py`**: Analyzes real-time execution quality, order book dynamics, and latency metrics.
11. **`ai/bridge/signal_packet.py`**: Data structure schema defining binary/JSON IPC payload between MQL5 and Python.
12. **`ai/bridge/vibe_multi_agent_engine.py`**: Multi-agent consensus engine synthesizing technical indicators and sentiment.
13. **`ai/bridge/vibe_trading_adapter.py`**: Adapter connecting AI decisions directly into the MT5 trade order dispatcher.

---

### 💻 Core Python Execution & Watchdogs (`root`)
14. **`bridge_247_watchdog.py`**: Fault-tolerant process monitor with heartbeat pings and auto-recovery for bridges.
15. **`config.yaml`**: Primary configuration file (risk limits, lot size formulas, spreads, ports, symbol lists).
16. **`requirements.txt`**: Python dependencies (`MetaTrader5`, `pyzmq`, `numpy`, `pandas`, `pyyaml`, etc.).
17. **`signal_match_validator.py`**: Tool to verify synchronization between MQL5 signals and Python execution logs.
18. **`super_fast_scalper.py`**: Core Python algorithmic engine executing ultra-low latency scalp signals.

---

### 📊 Web Telemetry Dashboard (`dashboard/`)
19. **`dashboard/app.js`**: Frontend JavaScript for charts, WebSocket/polling feeds, and live PnL cards.
20. **`dashboard/index.html`**: Premium HTML5 interface displaying real-time open positions, latency, and win rate.
21. **`dashboard/server.py`**: Lightweight HTTP/JSON backend server delivering telemetry metrics to the UI.
22. **`dashboard/styles.css`**: Dark-mode glassmorphic CSS styling for institutional aesthetic.

---

### 📈 MetaTrader 5 Expert Advisors (`.mq5` / `.ex5`)
23. **`Kronos_SuperFast_Scalper_EA.mq5`**: Main production Expert Advisor source code for MT5.
24. **`Kronos_SuperFast_Scalper_EA.ex5`**: Compiled production MT5 binary executable.
25. **`SmartScalper_V2.mq5`**: Institutional v2 architecture Expert Advisor with multi-layer SMC filtering.
26. **`SmartScalper_V2.ex5`**: Compiled v2 binary executable ready for live or demo MT5 charts.

---

### 🧩 MQL5 Modular Includes (`Include/SmartScalper/`)
27. **`SmartScalper_AIBridge.mqh`**: Low-latency IPC bridge connector transmitting ticks/signals to Python.
28. **`SmartScalper_Config.mqh`**: Parameter parsing, magic numbers, symbol properties, and time filters.
29. **`SmartScalper_FeatureEngine.mqh`**: Real-time feature calculation (velocity, momentum, tick acceleration).
30. **`SmartScalper_Filters.mqh`**: Spread, slippage, session, news, and time-of-day filters.
31. **`SmartScalper_HUD.mqh`**: On-chart GUI overlay showing current spread, regime, AI score, and daily PnL.
32. **`SmartScalper_Journal.mqh`**: High-speed tick and order event logger to CSV.
33. **`SmartScalper_MTF.mqh`**: Multi-timeframe trend and bias alignment engine (M1/M5/M15/H1).
34. **`SmartScalper_Regime.mqh`**: Market regime classifier (Trending vs Range-bound vs High-Volatility Choppy).
35. **`SmartScalper_RiskEngine.mqh`**: Dynamic lot calculation, max daily loss cutoff, and risk-per-trade controls.
36. **`SmartScalper_Scoring.mqh`**: Multi-factor signal scoring (requires min confidence threshold before trigger).
37. **`SmartScalper_SMC.mqh`**: Smart Money Concepts module (Order Blocks, Fair Value Gaps, Liquidity Sweeps).
38. **`SmartScalper_TradeManager.mqh`**: Order execution, breakeven trigger, trailing stop, and partial TP management.
39. **`SmartScalper_Types.mqh`**: Struct and enum definitions for signals, positions, and operational states.
40. **`SmartScalper_VolatilityShield.mqh`**: Dynamic circuit breaker against extreme flash spikes and widening spreads.

---

### 🧪 Test Suite & Validation Engines (`tests/`)
41. **`tests/ablation_study_engine.py`**: Isolates each indicator/filter to measure isolated edge and degradation.
42. **`tests/generate_risk_reconciliation.py`**: Generates statistical risk reconciliation between backtest and forward logs.
43. **`tests/multi_timeframe_backtester.py`**: Simulates concurrent MTF multi-symbol execution.
44. **`tests/phase3b_adversarial_engine.py`**: Tests bot under artificial slippage, delay, and extreme tick spikes.
45. **`tests/phase4_forward_validator.py`**: Validates forward trade consistency and detects drift.
46. **`tests/test_audit_engine.py`**: Automated code & latency benchmark test suite.
47. **`tests/test_audit_suite.mq5` / `.ex5`**: MQL5 unit test harness for all Include components.
48. **`tests/test_openai_tools.py`**: Unit tests for AI Assistant tool calls and response parsing.
49. **`tests/test_python_bridge.py`**: Stress tester for IPC socket latency and packet loss.
50. **`tests/test_smart_scalper_units.mq5` / `.ex5`**: Comprehensive MQL5 unit test suite.

---

### 📑 Reports & Research Artifacts (`.md` & `.csv`)
51. **`PHASE_2_VALIDATION_REPORT.md`**: Full phase 2 backtest and simulation validation findings.
52. **`PHASE_3A_ABLATION_REPORT.md`**: Factor ablation study isolating individual indicator contributions.
53. **`PHASE_3B_ADVERSARIAL_ROBUSTNESS_REPORT.md`**: Stress test report under slippage, spread expansion, and latency.
54. **`PHASE_3B_FROZEN_MANIFEST.md`**: Checksum hash manifest of frozen release code.
55. **`PHASE_4_DATA_PROVENANCE.md`**: Source data and tick feed audit.
56. **`PHASE_4_FORWARD_STATUS.md`**: Live / forward trading status and current scorecard.
57. **`PHASE_4_FORWARD_VALIDATION_REPORT.md`**: Empirical forward vs backtest parity analysis.
58. **`PHASE_4_FROZEN_RELEASE_MANIFEST.md`**: Final release lock state and version provenance.
59. **`SETUP_AND_ROLLBACK.md`** *(under `docs/`)*: Installation, MT5 setup, hotkey guide, and emergency rollback procedures.
60. **`COMMISSION_STRESS_RESULTS.csv`**: Commission sensitivity test matrix.
61. **`ENTRY_PERTURBATION_RESULTS.csv`**: Entry jitter / delay stress results.
62. **`EXECUTION_DELAY_RESULTS.csv`**: Latency penalty degradation curves.
63. **`FORWARD_RISK_RECONCILIATION.csv`**: Trade-by-trade forward reconciliation log.
64. **`MONTE_CARLO_RESULTS.csv`**: 1,000-run Monte Carlo drawdown and ruin probability distribution.
65. **`REGIME_RESULTS.csv`**: Performance breakdown by market regime.
66. **`SESSION_RESULTS.csv`**: Asian / London / NY session performance breakdown.
67. **`SLIPPAGE_STRESS_RESULTS.csv`**: Slippage stress test numbers.
68. **`SPREAD_STRESS_RESULTS.csv`**: Spread widening impact data.
69. **`SYMBOL_RESULTS.csv`**: Per-asset performance metrics (BTCUSD, XAUUSD, EURUSD, etc.).
70. **`TIMEFRAME_RESULTS.csv`**: Timeframe comparative metrics (M1 vs M5).
71. **`smart_scalper_forward_trades.csv`**: Realized forward trade record.
72. **`smart_scalper_shadow_signals.csv`**: Shadow signal capture log.
