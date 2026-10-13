"""
Super-Fast Institutional Scalping Bot (Vibe Waterfall Edition)
Engineered for:
- XAUUSD (Gold - Primary) & BTCUSD (Bitcoin - Secondary)
- Retest / Pullback Entry Optimization (Never Chases at the Extreme Low/High)
- Structural Candle-High/Low Stop Loss (Eliminates Noise Shakeouts)
- Candle-by-Candle Waterfall Trailing Engine
- Multi-Stage Dynamic Profit Locking (Step-Lock)
- 5-Minute Stagnation Exit Gatekeeper
- Dynamic Spread Gate
- 24/7 Continuous Auto-Restart Loop
"""

import sys
import os
import time
import json
import logging
import argparse
from datetime import datetime, timezone
import pandas as pd
import numpy as np
import MetaTrader5 as mt5

# Force UTF-8 stdout/stderr on Windows
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Setup paths
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
_PROJECT_ROOT = os.path.dirname(_THIS_DIR)

for p in [_THIS_DIR, _PROJECT_ROOT, os.path.join(_THIS_DIR, "ai", "bridge")]:
    if os.path.exists(p) and p not in sys.path:
        sys.path.insert(0, p)

from vibe_multi_agent_engine import VibeConvictionSizerMaster

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("WaterfallScalper")

class SuperFastScalper:
    def __init__(
        self,
        symbol: str = "XAUUSD",
        timeframe_str: str = "M5",
        enable_break_even: bool = True
    ):
        self.symbol = symbol.upper()
        self.timeframe_str = timeframe_str
        self.tf_enum = mt5.TIMEFRAME_M5 if timeframe_str == "M5" else mt5.TIMEFRAME_M1
        self.enable_break_even = enable_break_even
        
        # Dedicated Magic Numbers & Structural Buffers
        if "XAU" in self.symbol or "GOLD" in self.symbol:
            self.magic_number = 888222 # XAUUSD Gold Magic Number
            self.max_spread = 65 # Max points for Gold (6.5 pips)
            self.sl_buffer = 2.50 # Breathing buffer above/below candle ($2.50)
        else:
            self.magic_number = 888111 # BTCUSD Magic Number
            self.max_spread = 25 # Max points for BTC ($25)
            self.sl_buffer = 50.0 # Breathing buffer for BTC ($50.0)
            
        self.last_order_ts = 0.0
        self.last_candle_trade_ts = 0
        self.last_closed_candle_trail_ts = 0
        
        self.vibe_master = VibeConvictionSizerMaster(symbol=self.symbol)
        self._ensure_mt5()
        
        log.info(
            f"🏛️ KRONOS INSTITUTIONAL SCALPER ACTIVE | Symbol: {self.symbol} | "
            f"TF: {self.timeframe_str} | Magic: {self.magic_number} | Micro-Lot Scaling: ENABLED | Stagnation Exit: DISABLED"
        )

    def _ensure_mt5(self) -> bool:
        """Keeps MT5 connection alive with continuous auto-reconnection"""
        while True:
            try:
                if mt5.initialize():
                    selected = mt5.symbol_select(self.symbol, True)
                    if selected:
                        return True
                    else:
                        log.warning(f"Symbol {self.symbol} selection pending... Retrying in 2s")
                else:
                    log.warning(f"MT5 initialize failed: {mt5.last_error()}. Retrying in 3s...")
            except Exception as e:
                log.warning(f"MT5 connection exception: {e}. Retrying in 3s...")
            time.sleep(3)

    def fetch_live_candles(self, count: int = 200) -> pd.DataFrame:
        try:
            rates = mt5.copy_rates_from_pos(self.symbol, self.tf_enum, 0, count)
            if rates is None or len(rates) < 30:
                return None
            
            df = pd.DataFrame(rates)
            df['timestamps'] = pd.to_datetime(df['time'], unit='s')
            df['volume'] = df['tick_volume'].astype(float)
            df['amount'] = df['volume'] * df['close'].astype(float)
            return df[['timestamps', 'open', 'high', 'low', 'close', 'volume', 'amount']]
        except Exception as e:
            log.warning(f"Candle fetch error: {e}")
            self._ensure_mt5()
            return None

    def get_open_positions(self) -> list:
        try:
            positions = mt5.positions_get(symbol=self.symbol)
            if positions:
                return [p for p in positions if p.magic == self.magic_number]
        except Exception:
            self._ensure_mt5()
        return []

    def manage_waterfall_trailing_and_locks(
        self,
        df: pd.DataFrame,
        s1_trigger: float,
        s1_lock: float,
        s2_trigger: float,
        s2_lock: float,
        enable_trailing: bool = True
    ):
        """
        1. Break-Even Profit Lock (Stage 1): Moves SL to Entry + Lock once price reaches +1.0R (e.g. +$5.00 on Gold)
        2. Delayed Trailing Stop (Stage 2): Activates ONLY when trade reaches +1.5R (e.g. +$7.00 on Gold), trailing $3.00 behind price
        3. Stagnation Exit: Disabled to let winning setups expand to full Take-Profit
        """
        positions = self.get_open_positions()
        if not positions or len(df) < 5:
            return
            
        tick = mt5.symbol_info_tick(self.symbol)
        if not tick:
            return
            
        sym_info = mt5.symbol_info(self.symbol)
        digits = int(sym_info.digits) if sym_info else 2
        
        for pos in positions:
            entry_price = pos.price_open
            current_sl = pos.sl
            current_tp = pos.tp
            
            if pos.type == mt5.ORDER_TYPE_BUY:
                current_price = tick.bid
                profit_dist = current_price - entry_price
                
                # --- STAGE 2: DELAYED TRAILING STOP (+1.5R Profit) ---
                if enable_trailing and s2_trigger > 0 and profit_dist >= s2_trigger:
                    candidate_sl = round(current_price - s2_lock, digits)
                    # Advance SL only if it improves upon current SL by at least $0.50
                    if candidate_sl > current_sl and candidate_sl > entry_price:
                        req = {
                            "action": mt5.TRADE_ACTION_SLTP,
                            "position": pos.ticket,
                            "symbol": self.symbol,
                            "sl": candidate_sl,
                            "tp": current_tp,
                        }
                        res = mt5.order_send(req)
                        if res and res.retcode == mt5.TRADE_RETCODE_DONE:
                            log.info(f"🌊 [INSTITUTIONAL TRAIL] BUY #{pos.ticket} SL trailed to ${candidate_sl:.2f} (Locking Profit)")
                            
                # --- STAGE 1: BREAK-EVEN PROFIT LOCK (+1.0R Profit) ---
                elif s1_trigger > 0 and profit_dist >= s1_trigger:
                    target_sl = round(entry_price + s1_lock, digits)
                    if current_sl < target_sl or current_sl < entry_price:
                        req = {
                            "action": mt5.TRADE_ACTION_SLTP,
                            "position": pos.ticket,
                            "symbol": self.symbol,
                            "sl": target_sl,
                            "tp": current_tp,
                        }
                        res = mt5.order_send(req)
                        if res and res.retcode == mt5.TRADE_RETCODE_DONE:
                            log.info(f"🛡️ [BREAK-EVEN LOCK] BUY #{pos.ticket} SL moved to ${target_sl:.2f} (Locked +${s1_lock:.2f})")
                        
            elif pos.type == mt5.ORDER_TYPE_SELL:
                current_price = tick.ask
                profit_dist = entry_price - current_price
                
                # --- STAGE 2: DELAYED TRAILING STOP (+1.5R Profit) ---
                if enable_trailing and s2_trigger > 0 and profit_dist >= s2_trigger:
                    candidate_sl = round(current_price + s2_lock, digits)
                    if (candidate_sl < current_sl or current_sl == 0) and candidate_sl < entry_price:
                        req = {
                            "action": mt5.TRADE_ACTION_SLTP,
                            "position": pos.ticket,
                            "symbol": self.symbol,
                            "sl": candidate_sl,
                            "tp": current_tp,
                        }
                        res = mt5.order_send(req)
                        if res and res.retcode == mt5.TRADE_RETCODE_DONE:
                            log.info(f"🌊 [INSTITUTIONAL TRAIL] SELL #{pos.ticket} SL trailed to ${candidate_sl:.2f} (Locking Profit)")
                            
                # --- STAGE 1: BREAK-EVEN PROFIT LOCK (+1.0R Profit) ---
                elif s1_trigger > 0 and profit_dist >= s1_trigger:
                    target_sl = round(entry_price - s1_lock, digits)
                    if current_sl > target_sl or current_sl > entry_price or current_sl == 0:
                        req = {
                            "action": mt5.TRADE_ACTION_SLTP,
                            "position": pos.ticket,
                            "symbol": self.symbol,
                            "sl": target_sl,
                            "tp": current_tp,
                        }
                        res = mt5.order_send(req)
                        if res and res.retcode == mt5.TRADE_RETCODE_DONE:
                            log.info(f"🛡️ [BREAK-EVEN LOCK] SELL #{pos.ticket} SL moved to ${target_sl:.2f} (Locked +${s1_lock:.2f})")

    def execute_fast_order(self, action: str, price: float, sl: float, tp: float, lot: float, tier_label: str) -> bool:
        try:
            # 1. Spread Check Gate
            sym_info = mt5.symbol_info(self.symbol)
            if sym_info and sym_info.spread > self.max_spread:
                log.warning(f"⚠️ [SPREAD GATE] Spread {sym_info.spread} > {self.max_spread} points. Entry paused for optimal fill.")
                return False
                
            trade_type = mt5.ORDER_TYPE_BUY if action == "BUY" else mt5.ORDER_TYPE_SELL
            tick = mt5.symbol_info_tick(self.symbol)
            if not tick:
                self._ensure_mt5()
                return False
                
            exec_price = tick.ask if action == "BUY" else tick.bid
            digits = int(sym_info.digits) if sym_info else 2
            
            sl = round(sl, digits)
            tp = round(tp, digits)
            
            req = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": self.symbol,
                "volume": lot,
                "type": trade_type,
                "price": exec_price,
                "sl": sl,
                "tp": tp,
                "deviation": 25,
                "magic": self.magic_number,
                "comment": f"Vibe-WF-{tier_label[:4]}",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            
            start_t = time.time()
            res = mt5.order_send(req)
            latency_ms = (time.time() - start_t) * 1000
            
            if res and res.retcode == mt5.TRADE_RETCODE_DONE:
                self.last_order_ts = time.time()
                log.info(
                    f"⚡ [{tier_label}] TRADE EXECUTED! Action: {action} {lot:.2f} lots @ ${exec_price:.2f} | "
                    f"SL: ${sl:.2f} | TP: ${tp:.2f} | Latency: {latency_ms:.1f}ms | Ticket #{res.order}"
                )
                return True
            else:
                comment = res.comment if res else "Unknown"
                if "AutoTrading disabled" in comment or (res and res.retcode == 10027):
                    log.warning("⚠️ [ACTION REQUIRED] 'Algo Trading' is toggled OFF in MetaTrader 5! Please click the 'Algo Trading' button in MT5 toolbar to allow automated trade execution.")
                    time.sleep(3.0)
                else:
                    log.error(f"❌ Order Failed ({comment}) [retcode: {res.retcode if res else 'None'}]")
                return False
        except Exception as e:
            log.error(f"Execution exception: {e}")
            self._ensure_mt5()
            return False

    def _export_mql5_files(self, signal: str, confidence: float, forecast_prices: list, cur_close: float, lot: float, sl_dist: float, tp_dist: float) -> None:
        try:
            info = mt5.terminal_info()
            if not info:
                return
            
            dirs = [
                os.path.join(info.data_path, "MQL5", "Files"),
                os.path.join(info.commondata_path, "Files")
            ]
            
            now_ts = int(time.time() * 1000)
            sl = (cur_close - sl_dist) if signal == "BUY" else (cur_close + sl_dist)
            tp = (cur_close + tp_dist) if signal == "BUY" else (cur_close - tp_dist)

            sig_content = f"{now_ts},{signal},{cur_close:.2f},{sl:.2f},{tp:.2f},{lot:.2f},{confidence:.1f}\n"
            forecast_lines = [f"{p:.2f}" for p in forecast_prices]
            forecast_content = "\n".join(forecast_lines) + "\n"
            
            # JSON format for SmartScalper V2 on-chart HUD
            json_signal = {
                "symbol": self.symbol,
                "timestamp": int(time.time()),
                "direction": signal,
                "confidence": float(confidence),
                "regime_id": 1,
                "expected_move": float(tp_dist),
                "risk_score": float(sl_dist),
                "valid_for_seconds": 60,
                "reason_codes": f"MULTI_AGENT_{signal}_CONVICTION_{confidence:.1f}PCT"
            }
            json_str = json.dumps(json_signal, indent=2)

            for d in dirs:
                os.makedirs(d, exist_ok=True)
                with open(os.path.join(d, "kronos_signal.csv"), "w", encoding="ascii", errors="ignore") as f:
                    f.write(sig_content)
                with open(os.path.join(d, "kronos_forecast.csv"), "w", encoding="ascii", errors="ignore") as f:
                    f.write(forecast_content)
                with open(os.path.join(d, f"kronos_signal_{self.symbol}.csv"), "w", encoding="ascii", errors="ignore") as f:
                    f.write(sig_content)
                with open(os.path.join(d, f"kronos_forecast_{self.symbol}.csv"), "w", encoding="ascii", errors="ignore") as f:
                    f.write(forecast_content)
                with open(os.path.join(d, "smart_scalper_signal.json"), "w", encoding="utf-8", errors="ignore") as f:
                    f.write(json_str)
        except Exception:
            pass

    def run(self):
        log.info(f"🚀 Starting 24/7 Vibe Waterfall Scalper for {self.symbol} ({self.timeframe_str})...")
        
        while True:
            try:
                # 1. Fetch live candles
                df = self.fetch_live_candles(count=200)
                if df is None:
                    time.sleep(1)
                    continue
                    
                cur_close = float(df['close'].iloc[-1])
                cur_high = float(df['high'].iloc[-1])
                cur_low = float(df['low'].iloc[-1])
                cur_open = float(df['open'].iloc[-1])
                cur_candle_ts = int(df['timestamps'].iloc[-1].timestamp())
                
                # 2. Get Live Account Equity & Run Vibe-Trading Multi-Agent Consensus
                acc_info = mt5.account_info()
                current_equity = float(acc_info.equity) if acc_info and acc_info.equity > 0 else 500.0
                
                vibe_res = self.vibe_master.evaluate(df, account_equity=current_equity)
                
                direction = vibe_res["direction"]
                conviction = vibe_res["conviction"]
                tier = vibe_res["tier"]
                status_text = vibe_res["status_text"]
                lot_size = vibe_res["lot_size"]
                max_pos = vibe_res["max_positions"]
                tp_dist = vibe_res["tp_dist"]
                sl_dist = vibe_res["sl_dist"]
                s1_trigger = vibe_res["stage1_lock_trigger"]
                s1_lock = vibe_res["stage1_lock_val"]
                s2_trigger = vibe_res["stage2_lock_trigger"]
                s2_lock = vibe_res["stage2_lock_val"]
                forecast_prices = vibe_res["forecast_prices"]
                agents = vibe_res["agent_breakdown"]
                
                # 3. Manage Open Trades (Institutional Trailing & Break-Even Locks)
                self.manage_waterfall_trailing_and_locks(
                    df=df,
                    s1_trigger=s1_trigger,
                    s1_lock=s1_lock,
                    s2_trigger=s2_trigger,
                    s2_lock=s2_lock,
                    enable_trailing=True
                )
                
                # 4. Export Live Signal to MT5 IPC Files
                self._export_mql5_files(direction, conviction, forecast_prices, cur_close, lot_size, sl_dist, tp_dist)
                
                open_positions = self.get_open_positions()
                pos_count = len(open_positions)
                
                log.info(
                    f"🔄 [{self.symbol}] {status_text} | Eq: ${current_equity:.1f} | Dir: {direction} | Price: ${cur_close:.2f} | "
                    f"Agents: [SMC: {agents['smc']}, Trend: {agents['trend']}, Quant: {agents['quant']}] | Open: {pos_count}/{max_pos}"
                )
                
                # 5. Check Concurrency Ceiling
                if pos_count >= max_pos or direction == "HOLD" or lot_size <= 0:
                    time.sleep(0.5)
                    continue
                    
                # 6. WEEKEND & FRIDAY LIQUIDITY CUTOFF GATING (FOR FOREX & GOLD)
                # Note: Crypto (BTCUSD) trades 24/7 on weekends.
                is_forex_metal = ("XAU" in self.symbol or "GOLD" in self.symbol or "EUR" in self.symbol or "GBP" in self.symbol)
                if is_forex_metal:
                    utc_now = datetime.now(timezone.utc)
                    # Friday after 14:00 UTC: Block new entries to avoid weekend gap / spread blowout
                    if utc_now.weekday() == 4 and utc_now.hour >= 14:
                        time.sleep(1)
                        continue
                    # Saturday (5) or Sunday before 22:00 UTC (6): Weekend market closed
                    if utc_now.weekday() == 5 or (utc_now.weekday() == 6 and utc_now.hour < 22):
                        time.sleep(5)
                        continue
                    
                # 7. CANDLE-PACED GATE: Prevent churn re-entries in the same M5 candle
                now_sec = time.time()
                if cur_candle_ts == self.last_candle_trade_ts:
                    if tier != "TIER_1_MAX_SURETY" or (now_sec - self.last_order_ts) < 90.0:
                        time.sleep(0.5)
                        continue
                        
                # 8. Minimum Execution Cooldown
                if (now_sec - self.last_order_ts) < 45.0:
                    time.sleep(0.5)
                    continue
                    
                # 9. RETEST ENTRY FILTER (Never chase at the extreme low or high of candle)
                # For SELL: Don't sell if price is at the absolute bottom 15% of the active candle
                # For BUY: Don't buy if price is at the absolute top 15% of the active candle
                candle_range = (cur_high - cur_low) + 1e-9
                if direction == "SELL":
                    relative_pos = (cur_close - cur_low) / candle_range
                    if relative_pos < 0.15 and candle_range > (sl_dist * 0.6):
                        # Extreme low of expanding candle: wait for micro-retest
                        time.sleep(0.5)
                        continue
                elif direction == "BUY":
                    relative_pos = (cur_close - cur_low) / candle_range
                    if relative_pos > 0.85 and candle_range > (sl_dist * 0.6):
                        # Extreme high of expanding candle: wait for micro-retest
                        time.sleep(0.5)
                        continue

                # 10. Dynamic Structural Stop Loss (Above previous candle High for SELL / Below Low for BUY)
                prev_high = float(df['high'].iloc[-2])
                prev_low = float(df['low'].iloc[-2])
                
                if direction == "BUY":
                    structural_sl = min(prev_low, cur_low) - self.sl_buffer
                    # Ensure minimum safe distance
                    sl = min(structural_sl, cur_close - sl_dist)
                    tp = cur_close + tp_dist
                else:
                    structural_sl = max(prev_high, cur_high) + self.sl_buffer
                    # Ensure minimum safe distance
                    sl = max(structural_sl, cur_close + sl_dist)
                    tp = cur_close - tp_dist
                    
                log.info(f"🔥 [WATERFALL DISPATCH] Executing {direction} {lot_size:.2f} Lots ({status_text}). SL: ${sl:.2f} | TP: ${tp:.2f}...")
                success = self.execute_fast_order(action=direction, price=cur_close, sl=sl, tp=tp, lot=lot_size, tier_label=tier)
                if success:
                    self.last_candle_trade_ts = cur_candle_ts
                    time.sleep(0.5)
                else:
                    time.sleep(3.0)
                    
            except KeyboardInterrupt:
                log.info(f"[{self.symbol}] Shutdown requested by user.")
                break
            except Exception as e:
                log.error(f"[{self.symbol}] Error in scalper loop: {e}")
                self._ensure_mt5()
                time.sleep(1)

def main():
    parser = argparse.ArgumentParser(description="Vibe Waterfall Scalper")
    parser.add_argument("--symbol", type=str, default="XAUUSD", help="Trading symbol (default: XAUUSD)")
    parser.add_argument("--timeframe", type=str, default="M5", help="Timeframe string (default: M5)")
    args = parser.parse_args()
    
    scalper = SuperFastScalper(
        symbol=args.symbol,
        timeframe_str=args.timeframe,
        enable_break_even=True
    )
    scalper.run()

if __name__ == "__main__":
    main()
