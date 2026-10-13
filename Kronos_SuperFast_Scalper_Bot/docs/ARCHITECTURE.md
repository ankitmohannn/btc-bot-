# SmartScalper V2: System Architecture & Technical Specification

## 1. Overview
SmartScalper V2 is an institutional-grade, hybrid algorithmic trading platform developed for MetaTrader 5, enhanced by the research, market intelligence, and predictive scoring capabilities of **HKUDS Vibe-Trading**.

The system is built on strict separation of concerns:
- **MT5 EA (`SmartScalper_V2.mq5`)**: Deterministic execution, non-repainting Market Structure (SMC), Multi-Timeframe (MTF) analysis, institutional position sizing, dynamic Stop Loss / Take Profit, and risk protection circuit breakers.
- **Python AI Bridge (`ai/bridge/`)**: High-speed IPC service that processes multi-timeframe feature packets, computes machine learning confidence, validates market regimes, and supplies structured signal packets.
- **Vibe-Trading Research Subsystem**: Strategy hypothesis evaluation, post-trade attribution, Monte Carlo resampling, and walk-forward verification.

---

## 2. Hybrid System Architecture Diagram

```
+---------------------------------------------------------------------------------------------------+
|                                      HKUDS Vibe-Trading                                           |
|                            (Research, Backtesting, Attribution)                                   |
+-------------------------------------------------+-------------------------------------------------+
                                                  |
                                    Strategy / Regime Hypotheses
                                                  v
+---------------------------------------------------------------------------------------------------+
| Python AI Bridge (`ai/bridge/`)                                                                   |
|   - ai_bridge_server.py: Async IPC server (Socket / JSON Shared File)                             |
|   - vibe_trading_adapter.py: AI signal heuristics, confidence, and reason codes                   |
|   - research_evaluator.py: Trade journal ingestion, Monte Carlo (1000 iter), Sharpe, Attrib       |
+-------------------------------------------------+-------------------------------------------------+
                                                  | Structured JSON IPC (<10ms)
                                                  | Failsafe: AI offline -> Conf=0.0
                                                  v
+---------------------------------------------------------------------------------------------------+
| MetaTrader 5 Deterministic Execution Engine (`SmartScalper_V2.mq5`)                               |
|                                                                                                   |
|  +---------------------------+   +---------------------------+   +-----------------------------+  |
|  | Multi-Timeframe Matrix    |   | Non-Repainting SMC Engine |   | Market Regime Engine        |  |
|  | H1 / M15 / M5 / M1        |   | BOS, CHoCH, FVG, OB, BSL  |   | Trend / Range / Vol / News  |  |
|  +-------------+-------------+   +-------------+-------------+   +--------------+--------------+  |
|                |                               |                                |                 |
|                +-------------------------------+--------------------------------+                 |
|                                                |                                                  |
|                                                v                                                  |
|                                  +---------------------------+                                    |
|                                  | Explainable 0-100 Scoring |                                    |
|                                  | 10 Weighted Components    |                                    |
|                                  +-------------+-------------+                                    |
|                                                |                                                  |
|                                                v                                                  |
|                                  +---------------------------+                                    |
|                                  | Entry Quality Filter Gate |                                    |
|                                  | Spread / Session / Drawdown|                                   |
|                                  +-------------+-------------+                                    |
|                                                |                                                  |
|                                                v                                                  |
|                                  +---------------------------+                                    |
|                                  | Institutional Risk Engine |                                    |
|                                  | Equity % / Tick Math / SL |                                    |
|                                  +-------------+-------------+                                    |
|                                                |                                                  |
|                                                v                                                  |
|                                  +---------------------------+                                    |
|                                  | Execution & Trade Manager |                                    |
|                                  | Anti-Spam BE, Trail, HUD  |                                    |
|                                  +---------------------------+                                    |
+---------------------------------------------------------------------------------------------------+
```

---

## 3. Subsystem Breakdown

### 3.1 Non-Repainting Smart Money Concepts (SMC) Engine (`SmartScalper_SMC.mqh`)
- **Swing Points**: Scans left and right lookback bars (`InpSwingLookback` default 5) for unassailable swing highs and swing lows. Timestamped with exact bar indices.
- **Break of Structure (BOS)**: Confirmed only on candle close breaking previous swing highs (bullish) or swing lows (bearish).
- **Change of Character (CHoCH)**: Identifies trend reversal when price breaks against the prevailing series of Higher Lows (bearish CHoCH) or Lower Highs (bullish CHoCH).
- **Liquidity Sweeps (BSL / SSL)**:
  - **Buy-Side Liquidity (BSL) Sweep**: Bar high penetrates swing high by `InpSweepBufferPoints`, but bar close falls back below the swing level (bearish rejection).
  - **Sell-Side Liquidity (SSL) Sweep**: Bar low penetrates swing low by `InpSweepBufferPoints`, but bar close recovers back above the swing level (bullish rejection).
- **Fair Value Gaps (FVG)**:
  - Bullish: `Bar[i].Low > Bar[i+2].High`. Midpoint = 50% Consequent Encroachment. Tracks live mitigation status.
  - Bearish: `Bar[i].High < Bar[i+2].Low`.
- **Order Blocks (OB)**: Tracks institutional demand/supply footprints preceding structural displacement candles.
- **Premium / Discount Dealing Range**: Calculates the 50% equilibrium between active swing high and swing low. Enforces buying in Discount and selling in Premium.

### 3.2 Multi-Timeframe (MTF) Alignment Matrix (`SmartScalper_MTF.mqh`)
Synchronizes four timeframes in real time:
- **H1 (Macro Regime)**: 35% weight. Determines the macro institutional trend.
- **M15 (Intermediate Structure)**: 30% weight. Identifies key dealing ranges and order flow.
- **M5 (Primary Setup)**: 25% weight. Pinpoints SMC setups, FVG retests, and OB mitigations.
- **M1 (Execution Confirmation)**: 10% weight. Micro-momentum alignment.

### 3.3 Market Regime Engine (`SmartScalper_Regime.mqh`)
Classifies market state into 11 distinct regimes:
1. `REGIME_TRENDING_UP`: Bullish stacked EMAs, ADX > 22, DI+ > DI-.
2. `REGIME_TRENDING_DOWN`: Bearish stacked EMAs, ADX > 22, DI- > DI+.
3. `REGIME_RANGE`: Low ADX (< 20), neutral RSI (40-60).
4. `REGIME_HIGH_VOLATILITY`: ATR percentile > 85%, requires wider structural SL and 50% lot reduction.
5. `REGIME_LOW_VOLATILITY`: ATR percentile < 18%, suppresses false breakouts.
6. `REGIME_BREAKOUT` / `REGIME_BREAKDOWN`: Volume expansion + displacement candle breaking range.
7. `REGIME_REVERSAL`: Liquidity sweep + CHoCH + RSI divergence.
8. `REGIME_LIQUIDITY_EVENT`: Major liquidity sweep in progress.
9. `REGIME_NEWS_RISK`: Abnormal spread spike (> `InpMaxSpreadPoints`), blocks all new entries.
10. `REGIME_NO_TRADE`: Session inactive or filters triggered.

### 3.4 Explainable 0–100 Scoring Engine (`SmartScalper_Scoring.mqh`)
Every candidate trade is scored dynamically:
- **Trend Alignment**: 15 pts max
- **Market Structure (BOS/CHoCH)**: 15 pts max
- **Liquidity Sweeps**: 15 pts max
- **Momentum (RSI/MACD/ADX)**: 10 pts max
- **Volatility Regime**: 10 pts max
- **FVG / Order Block Tap**: 10 pts max
- **Multi-Timeframe Alignment**: 10 pts max
- **Spread Quality**: 5 pts max
- **Session Alignment**: 5 pts max
- **AI / Vibe Confidence**: 5 pts max
- **Total**: 100 pts.
- Thresholds: 0–59 = `NO_TRADE`, 60–69 = `WEAK`, 70–79 = `VALID`, 80–89 = `STRONG`, 90–100 = `EXTREME`.

### 3.5 Institutional Dynamic Risk Engine (`SmartScalper_RiskEngine.mqh`)
- **Formula**:
  $$\text{RiskAmount} = \text{AccountEquity} \times \frac{\text{RiskPercent}}{100}$$
  $$\text{LossPerLot} = \left(\frac{\text{EntryPrice} - \text{SLPrice}}{\text{TickSize}}\right) \times \text{TickValue}$$
  $$\text{RawLot} = \frac{\text{RiskAmount}}{\text{LossPerLot}}$$
- **Volume Step Normalization**: Clamped to `SYMBOL_VOLUME_MIN`, `SYMBOL_VOLUME_MAX`, and floored to `SYMBOL_VOLUME_STEP`.
- **Dynamic SL**: Safest level between nearest structural swing and ATR multiple (`InpATRMultiplierSL * ATR`).
- **Dynamic TP**: Targets opposing liquidity pool or enforces minimum strict Risk-to-Reward ratio floor (`InpMinimumRR` >= 1.5, preferred 2.0).

### 3.6 Resilient AI Bridge & Failsafe Subsystem (`SmartScalper_AIBridge.mqh`)
- Serializes `MqlFeaturePacket` to JSON; parses `MqlAISignalPacket`.
- **Offline Failsafe**: If Python is disconnected or signal TTL expires (>30s), `AI_CONFIDENCE = 0.0` and `ai_is_online = false`.
- If `InpAIRequiredForEntry = false` (default), the EA trades autonomously using its deterministic MQL5 engine.
- If `InpAIRequiredForEntry = true`, the EA halts new orders until AI reconnects.
- **Security Guarantee**: No free-form AI text or arbitrary shell commands can execute orders.
