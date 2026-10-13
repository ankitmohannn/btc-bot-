# Kronos SuperFast Scalper Bot (V2 Institutional Architecture)

Institutional AI-Enhanced MT5 Smart Scalper EA with Non-Repainting SMC (Smart Money Concepts), MTF Matrix, Regime Engine, Explainable 0-100 Scoring & 24/7 Telegram Signal Scanner.

## Key Features & Risk Architecture
- **SL-Free / Opposite Signal Exit**: Orders run without broker hard Stop Loss, allowing full breathing space during retests and pullbacks. Positions auto-liquidate instantly on confirmed opposite trend reversals (`CloseOppositePositions()`).
- **Hard Lot Ceiling (0.40 Lots Max)**: Sizing is strictly clamped across all risk and volatility shield layers (`NormalizeLotSize`, `VolatilityShield`, and EA execution engine).
- **Auto Break-Even Disabled**: Stop Loss is never dragged to entry price (`+$0.00`), preventing micro stop-outs from normal market noise.
- **Trend Stacking**: When trend momentum continues, scales in additional positions up to 10 concurrent open trades.
- **24/7 Telegram VIP Signal Scanner**: Dispatches real-time institutional signal cards with live MT5 market ticks, full SMC confluence reasons, and score breakdowns to both personal admin and VIP Telegram channels.

## Folder Structure
- `SmartScalper_V2.mq5` / `.ex5`: Main MT5 Expert Advisor.
- `Include/SmartScalper/`: Complete modular MQL5 architecture:
  - `SmartScalper_Config.mqh`: System-wide inputs and parameters.
  - `SmartScalper_RiskEngine.mqh`: Institutional lot calculation and dynamic SL/TP.
  - `SmartScalper_TradeManager.mqh`: Position execution, scaling, and flip exits.
  - `SmartScalper_SMC.mqh`: Market structure, Fair Value Gaps (FVG), and liquidity sweeps.
  - `SmartScalper_Telegram.mqh`: Real-time Telegram alert broadcaster.
  - `SmartScalper_VolatilityShield.mqh`: Parkinson volatility & Cornish-Fisher VaR 99% shield.
- `kronos_vip_signal_scanner.py`: Standalone Python multi-asset scanner.
- `run_vip_signal_scanner.bat`: 1-click launcher for background scanner.

## Installation & Deployment
1. Copy `Include/SmartScalper` to your MT5 `MQL5\Include\SmartScalper`.
2. Copy `SmartScalper_V2.mq5` to your MT5 `MQL5\Experts`.
3. Compile with MetaEditor 64.
4. Drag `SmartScalper_V2` onto a `BTCUSD M5` chart and ensure **Allow Algo Trading** is checked.
