"""
SmartScalper V2 - Discord Webhook Notifier
Sends periodic 45-minute automated performance and health telemetry updates.
"""

import os
import sys
import time
import json
import logging
import urllib.request
import urllib.error
from datetime import datetime, timedelta
import MetaTrader5 as mt5

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [DiscordNotifier] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
log = logging.getLogger("DiscordNotifier")

DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1541919464482938932/Cdg_UNgkMfak0TqzDJqKiJI95FGFbIhiWU3vuvLSIgeqxObOedYWrkUPvnbLgX4Teqpd"

class DiscordReporter:
    def __init__(self, webhook_url: str = DISCORD_WEBHOOK_URL, interval_minutes: int = 45):
        self.webhook_url = webhook_url
        self.interval_seconds = interval_minutes * 60
        self.running = True
        self.symbol = "XAUUSD"

    def _ensure_mt5(self):
        if not mt5.terminal_info():
            mt5.initialize()

    def get_account_and_trade_data(self):
        self._ensure_mt5()
        acc = mt5.account_info()
        term = mt5.terminal_info()
        
        balance = acc.balance if acc else 0.0
        equity = acc.equity if acc else 0.0
        floating_profit = acc.profit if acc else 0.0
        margin_free = acc.margin_free if acc else 0.0
        
        # Today's closed deals
        now = datetime.now()
        start_of_day = datetime(now.year, now.month, now.day)
        deals = mt5.history_deals_get(start_of_day, now + timedelta(days=1))
        
        today_pnl = 0.0
        today_wins = 0
        today_losses = 0
        today_trades_cnt = 0
        
        if deals:
            for d in deals:
                if d.entry == 1: # Deal entry out
                    profit = d.profit + d.commission + d.swap
                    today_pnl += profit
                    today_trades_cnt += 1
                    if profit > 0:
                        today_wins += 1
                    elif profit < 0:
                        today_losses += 1
                        
        today_win_rate = (today_wins / today_trades_cnt * 100.0) if today_trades_cnt > 0 else 0.0
        
        # Open positions
        open_positions = []
        positions = mt5.positions_get(symbol=self.symbol)
        if positions:
            for p in positions:
                open_positions.append({
                    "ticket": p.ticket,
                    "type": "BUY" if p.type == 0 else "SELL",
                    "volume": p.volume,
                    "price_open": p.price_open,
                    "price_current": p.price_current,
                    "sl": p.sl,
                    "tp": p.tp,
                    "profit": p.profit,
                    "comment": p.comment
                })
                
        # Read live signal & bridge status
        appdata = os.getenv("APPDATA", "")
        common_files = os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files")
        sig_csv = os.path.join(common_files, "kronos_signal.csv")
        sig_json = os.path.join(common_files, "smart_scalper_signal.json")
        
        live_signal = "HOLD"
        live_conf = 50.0
        live_price = 0.0
        signal_age_sec = 999.0
        
        if os.path.exists(sig_csv):
            try:
                with open(sig_csv, "r") as f:
                    line = f.read().strip()
                parts = line.split(",")
                if len(parts) >= 7:
                    live_signal = parts[1]
                    live_price = float(parts[2])
                    live_conf = float(parts[6])
                    signal_age_sec = time.time() - os.path.getmtime(sig_csv)
            except Exception:
                pass
                
        return {
            "balance": balance,
            "equity": equity,
            "floating_profit": floating_profit,
            "margin_free": margin_free,
            "today_pnl": today_pnl,
            "today_wins": today_wins,
            "today_losses": today_losses,
            "today_trades": today_trades_cnt,
            "today_win_rate": today_win_rate,
            "open_positions": open_positions,
            "live_signal": live_signal,
            "live_conf": live_conf,
            "live_price": live_price,
            "signal_age_sec": signal_age_sec,
            "connected": term.connected if term else False,
            "trade_allowed": term.trade_allowed if term else False
        }

    def send_discord_update(self, is_startup: bool = False):
        try:
            data = self.get_account_and_trade_data()
            
            # Embed color: Gold (0xFFD700) or Green (0x00FF00) or Red (0xFF0000)
            if data["today_pnl"] > 0:
                color = 0x00FF7F # Spring Green
            elif data["today_pnl"] < 0:
                color = 0xFF4500 # Orange Red
            else:
                color = 0xFFD700 # Gold
                
            title = "🚀 SmartScalper V2 — 45-Min Automated Bot Telemetry" if not is_startup else "🟢 SmartScalper V2 — 24/7 Discord Telemetry Connected"
            
            pos_desc = ""
            if data["open_positions"]:
                for pos in data["open_positions"]:
                    pnl_sign = "+" if pos["profit"] >= 0 else ""
                    pos_desc += f"• **{pos['type']} {pos['volume']} Lot** @ `${pos['price_open']:.2f}` | PnL: **{pnl_sign}${pos['profit']:.2f}** | SL: `${pos['sl']:.2f}` | TP: `${pos['tp']:.2f}`\n"
            else:
                pos_desc = "• *No active open positions (Searching optimal Retest setup)*\n"
                
            bridge_status = "🟢 ONLINE (Streaming <1s)" if data["signal_age_sec"] < 10 else f"⚠️ DELAYED ({data['signal_age_sec']:.0f}s)"
            pnl_emoji = "📈" if data["today_pnl"] >= 0 else "📉"
            pnl_str = f"+${data['today_pnl']:.2f}" if data["today_pnl"] >= 0 else f"-${abs(data['today_pnl']):.2f}"
            floating_str = f"+${data['floating_profit']:.2f}" if data["floating_profit"] >= 0 else f"-${abs(data['floating_profit']):.2f}"
            
            embed = {
                "title": title,
                "description": f"**Asset**: `XAUUSD (Gold M5)` | **Timestamp**: `<t:{int(time.time())}:F>`",
                "color": color,
                "fields": [
                    {
                        "name": "💰 Account Equity & Margin",
                        "value": f"**Equity**: `${data['equity']:,.2f}`\n**Balance**: `${data['balance']:,.2f}`\n**Floating PnL**: `{floating_str}`\n**Free Margin**: `${data['margin_free']:,.2f}`",
                        "inline": True
                    },
                    {
                        "name": f"{pnl_emoji} Today's Realized Performance",
                        "value": f"**Net PnL**: **`{pnl_str}`**\n**Trades**: `{data['today_trades']}` (Wins: `{data['today_wins']}`, Loss: `{data['today_losses']}`)\n**Win Rate**: **`{data['today_win_rate']:.1f}%`**",
                        "inline": True
                    },
                    {
                        "name": "🛡️ 24/7 Bridge & Market Status",
                        "value": f"**AI Bridge**: `{bridge_status}`\n**Market Price**: `${data['live_price']:.2f}`\n**Multi-Agent Signal**: `{data['live_signal']}` ({data['live_conf']:.1f}%)\n**MT5 Algo Trading**: `{'ACTIVE 🟢' if data['trade_allowed'] else 'DISABLED 🔴'}`",
                        "inline": False
                    },
                    {
                        "name": f"⚡ Active Positions ({len(data['open_positions'])} Open)",
                        "value": pos_desc,
                        "inline": False
                    }
                ],
                "footer": {
                    "text": "SmartScalper V2 + Volatility Shield 24/7 Automated Guardian",
                    "icon_url": "https://cdn-icons-png.flaticon.com/512/2620/2620602.png"
                },
                "timestamp": datetime.utcnow().isoformat()
            }
            
            payload = {
                "username": "Kronos Institutional Scalper",
                "avatar_url": "https://cdn-icons-png.flaticon.com/512/2620/2620602.png",
                "embeds": [embed]
            }
            
            data_bytes = json.dumps(payload).encode("utf-8")
            req = urllib.request.Request(
                self.webhook_url,
                data=data_bytes,
                headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
            )
            
            with urllib.request.urlopen(req, timeout=10) as response:
                status_code = response.getcode()
                if status_code in (200, 204):
                    log.info(f"✅ Discord update successfully sent! (Status: {status_code})")
                    return True
                else:
                    log.error(f"❌ Discord webhook status: {status_code}")
                    return False
                
        except Exception as e:
            log.error(f"Error sending Discord update: {e}")
            return False

    def start_loop(self):
        log.info(f"🚀 Discord 45-Minute Telemetry Loop Started...")
        # Send immediate confirmation message
        self.send_discord_update(is_startup=True)
        
        while self.running:
            try:
                time.sleep(self.interval_seconds)
                self.send_discord_update(is_startup=False)
            except KeyboardInterrupt:
                log.info("Discord loop stopped by user.")
                break
            except Exception as e:
                log.error(f"Loop error: {e}")
                time.sleep(10)

if __name__ == "__main__":
    reporter = DiscordReporter(interval_minutes=45)
    reporter.start_loop()
