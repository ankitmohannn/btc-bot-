"""
Vibe-Trading Multi-Agent Institutional Consensus & Sizing Engine (Universal Multi-Asset Edition)
Fully Supports:
- XAUUSD (Gold): Precision SMC Swing Trailing, 0.05-0.08 Lots, Candle-High/Low Structural SL
- BTCUSD (Bitcoin): Dynamic 4-Tier Volatility Sizing

Agents:
1. SMC & Market Structure Sentinel (BOS, CHoCH, Liquidity Sweeps, Wick Rejections)
2. Macro Trend & Momentum Flow Agent (EMA Fan 9/21/50/200, ADX, RSI Momentum)
3. Kronos Quant Forecast & Volatility Engine (3-Horizon Fast Trajectory Projection)
4. Vibe Conviction & Waterfall Master Sizer (Multi-Stage Step-Locking, Candle Trailing)
"""

import math
import time
import logging
from typing import Dict, List, Any, Optional
import pandas as pd
import numpy as np

log = logging.getLogger("VibeMultiAgent")

class MarketStructureAgent:
    """Agent 1: Detects institutional market structure, liquidity sweeps, and order blocks."""
    def analyze(self, df: pd.DataFrame) -> Dict[str, Any]:
        if len(df) < 20:
            return {"bias": "NEUTRAL", "confidence": 50.0, "reasons": ["INSUFFICIENT_DATA"]}
        
        recent_highs = df['high'].iloc[-15:-1]
        recent_lows = df['low'].iloc[-15:-1]
        cur_high = float(df['high'].iloc[-1])
        cur_low = float(df['low'].iloc[-1])
        cur_close = float(df['close'].iloc[-1])
        cur_open = float(df['open'].iloc[-1])
        
        highest_prev = float(recent_highs.max())
        lowest_prev = float(recent_lows.min())
        
        score_bull = 0.0
        score_bear = 0.0
        reasons = []
        
        # 1. Liquidity Sweeps (Fakeout & Reversal)
        if cur_high > highest_prev and cur_close < highest_prev:
            score_bear += 40.0
            reasons.append("BSL_SWEPT_BEARISH_REVERSAL")
        elif cur_low < lowest_prev and cur_close > lowest_prev:
            score_bull += 40.0
            reasons.append("SSL_SWEPT_BULLISH_REVERSAL")
            
        # 2. Break of Structure (BOS - Clean Momentum Expansion)
        if cur_close > highest_prev:
            score_bull += 35.0
            reasons.append("BOS_BULLISH_EXPANSION")
        elif cur_close < lowest_prev:
            score_bear += 35.0
            reasons.append("BOS_BEARISH_EXPANSION")
            
        # 3. Candle Wick Exhaustion (Anti-Top/Bottom Filter)
        upper_wick = cur_high - max(cur_open, cur_close)
        lower_wick = min(cur_open, cur_close) - cur_low
        body_size = abs(cur_close - cur_open) + 1e-9
        
        if upper_wick > (body_size * 2.0) and cur_close > highest_prev * 0.998:
            score_bear += 25.0
            reasons.append("TOP_WICK_EXHAUSTION_REJECTION")
        elif lower_wick > (body_size * 2.0) and cur_close < lowest_prev * 1.002:
            score_bull += 25.0
            reasons.append("BOTTOM_WICK_EXHAUSTION_REJECTION")
            
        # 4. Sequential Micro-Trend (Lower Highs / Higher Lows)
        lows_series = df['low'].iloc[-5:].values
        highs_series = df['high'].iloc[-5:].values
        if lows_series[-1] > lows_series[0] and highs_series[-1] > highs_series[0]:
            score_bull += 20.0
            reasons.append("HIGHER_LOW_WATERFALL_FLOW")
        elif lows_series[-1] < lows_series[0] and highs_series[-1] < highs_series[0]:
            score_bear += 20.0
            reasons.append("LOWER_HIGH_WATERFALL_FLOW")
            
        if score_bull > score_bear:
            bias = "BUY"
            confidence = min(98.0, 50.0 + score_bull)
        elif score_bear > score_bull:
            bias = "SELL"
            confidence = min(98.0, 50.0 + score_bear)
        else:
            bias = "NEUTRAL"
            confidence = 50.0
            reasons.append("RANGE_CONSOLIDATION")
            
        return {
            "bias": bias,
            "confidence": confidence,
            "reasons": reasons
        }

class TrendMomentumAgent:
    """Agent 2: Evaluates EMA Fan Alignment (9/21/50/200), RSI Momentum & Anti-Exhaustion."""
    def analyze(self, df: pd.DataFrame) -> Dict[str, Any]:
        if len(df) < 30:
            return {"bias": "NEUTRAL", "confidence": 50.0, "rsi": 50.0, "reasons": ["INSUFFICIENT_DATA"]}
            
        close = df['close']
        ema9 = float(close.ewm(span=9, adjust=False).mean().iloc[-1])
        ema21 = float(close.ewm(span=21, adjust=False).mean().iloc[-1])
        ema50 = float(close.ewm(span=50, adjust=False).mean().iloc[-1])
        cur_close = float(close.iloc[-1])
        
        # RSI 14
        delta = close.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean().iloc[-1]
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean().iloc[-1]
        rs = gain / (loss + 1e-9)
        rsi = float(100 - (100 / (1 + rs))) if not np.isnan(rs) else 50.0
        
        score_bull = 0.0
        score_bear = 0.0
        reasons = []
        
        # 1. EMA Fan Alignment
        if ema9 > ema21 and ema21 > ema50:
            score_bull += 40.0
            reasons.append("EMA_FAN_PERFECT_BULLISH")
        elif ema9 < ema21 and ema21 < ema50:
            score_bear += 40.0
            reasons.append("EMA_FAN_PERFECT_BEARISH")
            
        # 2. Dynamic Price Relation to EMA 9 / EMA 21
        if cur_close > ema9:
            score_bull += 15.0
        elif cur_close < ema9:
            score_bear += 15.0
            
        # 3. RSI Momentum Zones & Anti-Exhaustion
        if 48.0 <= rsi <= 68.0:
            score_bull += 25.0
            reasons.append(f"RSI_HEALTHY_BULLISH_{rsi:.1f}")
        elif 32.0 <= rsi <= 52.0:
            score_bear += 25.0
            reasons.append(f"RSI_HEALTHY_BEARISH_{rsi:.1f}")
        elif rsi > 78.0:
            score_bear += 30.0
            reasons.append("RSI_OVERBOUGHT_REVERSAL_RISK")
        elif rsi < 22.0:
            score_bull += 30.0
            reasons.append("RSI_OVERSOLD_REVERSAL_RISK")
            
        if score_bull > score_bear:
            bias = "BUY"
            confidence = min(98.0, 50.0 + score_bull)
        elif score_bear > score_bull:
            bias = "SELL"
            confidence = min(98.0, 50.0 + score_bear)
        else:
            bias = "NEUTRAL"
            confidence = 50.0
            
        return {
            "bias": bias,
            "confidence": confidence,
            "rsi": rsi,
            "reasons": reasons
        }

class KronosForecastAgent:
    """Agent 3: Quant Forecast Model for multi-horizon price trajectories and ATR volatility."""
    def analyze(self, df: pd.DataFrame) -> Dict[str, Any]:
        if len(df) < 14:
            return {"bias": "NEUTRAL", "confidence": 50.0, "atr": 5.0, "forecast_prices": [float(df['close'].iloc[-1])]}
            
        close = float(df['close'].iloc[-1])
        ema9 = float(df['close'].ewm(span=9, adjust=False).mean().iloc[-1])
        ema21 = float(df['close'].ewm(span=21, adjust=False).mean().iloc[-1])
        
        slope = (ema9 - ema21) / (close + 1e-9)
        tr = np.maximum(df['high'] - df['low'], np.abs(df['high'] - df['close'].shift(1)))
        atr = float(tr.rolling(14).mean().iloc[-1]) if len(df) >= 14 else 5.0
        
        pred_close_h3 = close + (slope * close * 2.0)
        forecast_prices = [close + (slope * close * (i + 1) * 0.5) for i in range(6)]
        
        fqs = min(96.0, max(65.0, 72.0 + (abs(slope) * 6000.0)))
        bias = "BUY" if slope >= 0 else "SELL"
        
        return {
            "bias": bias,
            "confidence": fqs,
            "predicted_close": pred_close_h3,
            "atr": max(atr, 2.0),
            "forecast_prices": forecast_prices
        }

class VibeConvictionSizerMaster:
    """
    Agent 4 (Master Sizer): Synthesizes all agents into unified conviction and asset-specific sizing.
    """
    def __init__(self, symbol: str = "BTCUSD"):
        self.symbol = symbol.upper()

        self.smc_agent = MarketStructureAgent()
        self.trend_agent = TrendMomentumAgent()
        self.kronos_agent = KronosForecastAgent()

    def evaluate(self, df: pd.DataFrame, account_equity: float = 6800.0) -> Dict[str, Any]:
        smc = self.smc_agent.analyze(df)
        trend = self.trend_agent.analyze(df)
        kronos = self.kronos_agent.analyze(df)
        
        cur_close = float(df['close'].iloc[-1])
        atr = kronos.get("atr", 5.0)
        is_gold = ("XAU" in self.symbol or "GOLD" in self.symbol)
        
        # Calculate Weighted Multi-Agent Consensus
        buy_weight = 0.0
        sell_weight = 0.0
        
        # SMC Agent Weight: 40%
        if smc["bias"] == "BUY": buy_weight += 0.40 * (smc["confidence"] / 100.0)
        elif smc["bias"] == "SELL": sell_weight += 0.40 * (smc["confidence"] / 100.0)
        
        # Trend Agent Weight: 35%
        if trend["bias"] == "BUY": buy_weight += 0.35 * (trend["confidence"] / 100.0)
        elif trend["bias"] == "SELL": sell_weight += 0.35 * (trend["confidence"] / 100.0)
        
        # Kronos Agent Weight: 25%
        if kronos["bias"] == "BUY": buy_weight += 0.25 * (kronos["confidence"] / 100.0)
        elif kronos["bias"] == "SELL": sell_weight += 0.25 * (kronos["confidence"] / 100.0)
        
        # Consensus Decision
        if buy_weight > sell_weight and buy_weight >= 0.50:
            direction = "BUY"
            raw_conviction = (buy_weight / 0.85) * 100.0
        elif sell_weight > buy_weight and sell_weight >= 0.50:
            direction = "SELL"
            raw_conviction = (sell_weight / 0.85) * 100.0
        else:
            direction = "HOLD"
            raw_conviction = 50.0
            
        conviction = round(min(98.5, max(40.0, raw_conviction)), 1)
        
        # --- DYNAMIC MICRO-LOT SIZING ENGINE (ACCOUNT GROWTH) ---
        # Formula: Base 0.01 lot + 0.01 per $500 equity, clamped to max 1.00 lot
        valid_equity = max(100.0, float(account_equity)) if account_equity else 500.0
        calculated_micro_lots = max(0.01, math.floor(valid_equity / 500.0) * 0.01)
        base_dynamic_lot = round(min(1.00, calculated_micro_lots), 2)
        
        # Asset Specific Sizing & Target Matrix (Institutional Breathing-Room Edition)
        if is_gold:
            # === XAUUSD (GOLD) CONFIGURATION ===
            # Target: 1:2 to 1:2.5 RR, Wide Trailing Buffer ($3.00), No Early Suffocation
            if conviction >= 85.0 and direction in ("BUY", "SELL"):
                tier = "TIER_1_MAX_SURETY"
                lot_size = base_dynamic_lot
                max_positions = 1
                tp_dist = 11.00                   # Expanded +$11.00 TP
                sl_dist = max(atr * 0.95, 4.50)    # $4.50 - $5.00 Structural SL
                stage1_lock_trigger = 5.50         # BE Trigger: Only after +$5.50 profit
                stage1_lock_val = 1.00             # Lock +$1.00 profit
                stage2_lock_trigger = 7.50         # Trailing Trigger: Only after +$7.50 (+1.5R)
                stage2_lock_val = 3.50             # Trail $3.50 behind price (1.5x ATR)
                status_text = f"🔥 GOLD TIER 1 (MAX SURETY: {conviction:.1f}% | Lot: {lot_size:.2f})"
            elif conviction >= 72.0 and direction in ("BUY", "SELL"):
                tier = "TIER_2_HIGH_CONVICTION"
                lot_size = base_dynamic_lot
                max_positions = 1
                tp_dist = 9.00                    # +$9.00 TP
                sl_dist = max(atr * 0.85, 4.20)    # $4.20 - $4.50 Structural SL
                stage1_lock_trigger = 5.00         # BE Trigger: Only after +$5.00 profit
                stage1_lock_val = 0.80             # Lock +$0.80 profit
                stage2_lock_trigger = 7.00         # Trailing Trigger: After +$7.00 profit
                stage2_lock_val = 3.00             # Trail $3.00 behind price
                status_text = f"⚡ GOLD TIER 2 (HIGH CONVICTION: {conviction:.1f}% | Lot: {lot_size:.2f})"
            elif conviction >= 65.0 and direction in ("BUY", "SELL"):
                tier = "TIER_3_MODERATE"
                lot_size = 0.01                    # Micro-test lot
                max_positions = 1
                tp_dist = 7.50
                sl_dist = max(atr * 0.75, 3.80)
                stage1_lock_trigger = 4.50
                stage1_lock_val = 0.50
                stage2_lock_trigger = 999.0        # Trailing disabled for micro-tier
                stage2_lock_val = 0.0
                status_text = f"🛡️ GOLD TIER 3 (MODERATE: {conviction:.1f}% | Lot: 0.01)"
            else:
                tier = "TIER_4_CHOP_BLOCKED"
                direction = "HOLD"
                lot_size = 0.0
                max_positions = 0
                tp_dist = 0.0
                sl_dist = 0.0
                stage1_lock_trigger = 0.0
                stage1_lock_val = 0.0
                stage2_lock_trigger = 0.0
                stage2_lock_val = 0.0
                status_text = f"⏳ GOLD TIER 4 (CHOP FILTERED: {conviction:.1f}%)"
        else:
            # === BTCUSD CONFIGURATION ===
            # Target: 1:2.1 RR, Wide Trailing Buffer ($75)
            if conviction >= 85.0 and direction in ("BUY", "SELL"):
                tier = "TIER_1_MAX_SURETY"
                lot_size = base_dynamic_lot
                max_positions = 1
                tp_dist = 280.0                   # Expanded +$280 TP
                sl_dist = max(atr * 1.0, 130.0)    # $130 Structural SL
                stage1_lock_trigger = 160.0        # BE Trigger: +$160 profit
                stage1_lock_val = 25.0             # Lock +$25 profit
                stage2_lock_trigger = 200.0        # Trailing Trigger: +$200 profit
                stage2_lock_val = 80.0             # Trail $80 behind price
                status_text = f"🔥 BTC TIER 1 (MAX SURETY: {conviction:.1f}% | Lot: {lot_size:.2f})"
            elif conviction >= 72.0 and direction in ("BUY", "SELL"):
                tier = "TIER_2_HIGH_CONVICTION"
                lot_size = base_dynamic_lot
                max_positions = 1
                tp_dist = 240.0                   # +$240 TP
                sl_dist = max(atr * 0.9, 115.0)    # $115 Structural SL
                stage1_lock_trigger = 140.0        # BE Trigger: +$140 profit
                stage1_lock_val = 20.0             # Lock +$20 profit
                stage2_lock_trigger = 180.0        # Trailing Trigger: +$180 profit
                stage2_lock_val = 70.0             # Trail $70 behind price
                status_text = f"⚡ BTC TIER 2 (HIGH CONVICTION: {conviction:.1f}% | Lot: {lot_size:.2f})"
            elif conviction >= 65.0 and direction in ("BUY", "SELL"):
                tier = "TIER_3_MODERATE"
                lot_size = 0.01                    # Micro-test lot
                max_positions = 1
                tp_dist = 180.0
                sl_dist = max(atr * 0.8, 95.0)
                stage1_lock_trigger = 110.0
                stage1_lock_val = 15.0
                stage2_lock_trigger = 999.0
                stage2_lock_val = 0.0
                status_text = f"🛡️ BTC TIER 3 (MODERATE: {conviction:.1f}% | Lot: 0.01)"
            else:
                tier = "TIER_4_CHOP_BLOCKED"
                direction = "HOLD"
                lot_size = 0.0
                max_positions = 0
                tp_dist = 0.0
                sl_dist = 0.0
                stage1_lock_trigger = 0.0
                stage1_lock_val = 0.0
                stage2_lock_trigger = 0.0
                stage2_lock_val = 0.0
                status_text = f"⏳ BTC TIER 4 (CHOP FILTERED: {conviction:.1f}%)"
            
        all_reasons = smc.get("reasons", []) + trend.get("reasons", [])
        
        return {
            "direction": direction,
            "conviction": conviction,
            "tier": tier,
            "status_text": status_text,
            "lot_size": lot_size,
            "max_positions": max_positions,
            "tp_dist": tp_dist,
            "sl_dist": sl_dist,
            "stage1_lock_trigger": stage1_lock_trigger,
            "stage1_lock_val": stage1_lock_val,
            "stage2_lock_trigger": stage2_lock_trigger,
            "stage2_lock_val": stage2_lock_val,
            "atr": atr,
            "forecast_prices": kronos.get("forecast_prices", [cur_close]),
            "agent_breakdown": {
                "smc": f"{smc['bias']} ({smc['confidence']:.1f}%)",
                "trend": f"{trend['bias']} ({trend['confidence']:.1f}%)",
                "quant": f"{kronos['bias']} ({kronos['confidence']:.1f}%)"
            },
            "reasons": all_reasons
        }
