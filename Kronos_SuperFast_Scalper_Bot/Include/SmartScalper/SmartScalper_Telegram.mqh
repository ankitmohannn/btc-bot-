//+------------------------------------------------------------------+
//|                                    SmartScalper_Telegram.mqh     |
//|                                  Copyright 2026, Institutional AI|
//|           Institutional Telegram Signal & Trade Alert Dispatcher |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.20"
#property strict

#include "SmartScalper_Types.mqh"

//+------------------------------------------------------------------+
//| Telegram Notification Engine Class                               |
//+------------------------------------------------------------------+
class CSmartTelegram
  {
private:
   string            m_bot_token;
   string            m_chat_id;
   bool              m_enabled;

   // Signal throttle to avoid duplicate spam
   string            m_last_signal_dir;
   datetime          m_last_signal_time;
   int               m_signal_throttle_secs;  // Min seconds between same-direction signal alerts

   // URL encode query strings for WebRequest
   string UrlEncode(string text)
     {
      string result = "";
      uchar src[];
      StringToCharArray(text, src);
      int len = ArraySize(src) - 1;

      for(int i = 0; i < len; i++)
        {
         uchar c = src[i];
         if((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
           {
            result += CharToString(c);
           }
         else if(c == ' ')
           {
            result += "%20";
           }
         else if(c == '\n')
           {
            result += "%0A";
           }
         else
           {
            result += StringFormat("%%%02X", c);
           }
        }
      return result;
     }

public:
   CSmartTelegram() : m_bot_token(""), m_chat_id(""), m_enabled(false),
                      m_last_signal_dir(""), m_last_signal_time(0), m_signal_throttle_secs(300) {}

   void Init(bool enabled, string bot_token, string chat_id)
     {
      m_enabled = enabled;
      m_bot_token = bot_token;
      m_chat_id = chat_id;
      m_signal_throttle_secs = 300;  // 5 minutes between same-direction signal alerts
     }

   bool IsConfigured()
     {
      return (m_enabled && m_bot_token != "" && m_chat_id != "");
     }

   bool SendMessage(string message)
     {
      if(!IsConfigured()) return false;

      string url = StringFormat("https://api.telegram.org/bot%s/sendMessage", m_bot_token);
      string headers = "Content-Type: application/json\r\n";

      // Escape message for JSON payload
      string json_text = "";
      uchar src[];
      StringToCharArray(message, src);
      int len = ArraySize(src) - 1;
      for(int i = 0; i < len; i++)
        {
         uchar c = src[i];
         if(c == '\"')      json_text += "\\\"";
         else if(c == '\\') json_text += "\\\\";
         else if(c == '\n') json_text += "\\n";
         else if(c == '\r') json_text += "\\r";
         else if(c == '\t') json_text += "\\t";
         else               json_text += CharToString(c);
        }

      string chat_ids[];
      int chat_count = StringSplit(m_chat_id, ',', chat_ids);
      if(chat_count <= 0)
        {
         ArrayResize(chat_ids, 1);
         chat_ids[0] = m_chat_id;
         chat_count = 1;
        }

      bool any_success = false;
      for(int k = 0; k < chat_count; k++)
        {
         string target_id = chat_ids[k];
         StringTrimLeft(target_id);
         StringTrimRight(target_id);
         if(target_id == "") continue;

         string payload = StringFormat("{\"chat_id\":\"%s\",\"text\":\"%s\"}", target_id, json_text);

         char post_data[];
         int req_len = StringToCharArray(payload, post_data, 0, WHOLE_ARRAY, CP_UTF8);
         if(req_len > 1) ArrayResize(post_data, req_len - 1);

         char result_data[];
         string result_headers = "";
         int timeout = 5000;

         ResetLastError();
         int res = WebRequest("POST", url, headers, timeout, post_data, result_data, result_headers);
         if(res == 200) any_success = true;
         else
           {
            int err = GetLastError();
            if(err == 4014)
              {
               Print("⚠️ [TELEGRAM] WebRequest not permitted! In MT5: Tools -> Options -> Expert Advisors -> check 'Allow WebRequest' and add: https://api.telegram.org");
              }
            else
              {
               PrintFormat("⚠️ [TELEGRAM] Error sending alert to %s: %d (res=%d)", target_id, err, res);
              }
           }
        }
      return any_success;
     }

   //+---------------------------------------------------------------+
   //| Send VIP Institutional Trade Executed Alert with Full Reasons |
   //+---------------------------------------------------------------+
   void SendVIPTradeAlert(string symbol, string dir, double lot, double price,
                          double sl, double tp1, double tp2,
                          const MqlScoreBreakdown &bd,
                          string regime_str, string session_str, double atr)
     {
      if(!IsConfigured()) return;
      string icon = (dir == "BUY") ? "🟢" : "🔴";
      string grade = (bd.total_score >= 80.0) ? "A+ Institutional Grade" :
                     (bd.total_score >= 90.0) ? "S-Tier Sniper" : "Valid Setup";

      double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(pt <= 0.0) pt = 0.01;
      int dig = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      double sl_dist_pts = (sl > 0.0) ? (MathAbs(price - sl) / pt) : 0.0;
      double tp1_dist_pts = MathAbs(tp1 - price) / pt;
      double tp2_dist_pts = MathAbs(tp2 - price) / pt;

      string curr_prefix = (StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "USD") >= 0) ? "$" : "";
      string sl_display = (sl > 0.0) ? StringFormat("%s%s (-%.0f pts)", curr_prefix, DoubleToString(sl, dig), sl_dist_pts) :
                                       "Opposite Signal Reversal 🔄 (No tight stop)";

      string msg = StringFormat(
         "🌟 VIP INSTITUTIONAL SIGNAL ALERT 🌟\n" +
         "═════════════════════════════════\n" +
         "💎 Symbol: %s  |  Timeframe: M15\n" +
         "⚡ Direction: STRONG %s %s\n" +
         "📊 Confidence Score: %.0f%% [%s]\n" +
         "═════════════════════════════════\n" +
         "📍 Entry Price: %s%s\n" +
         "🛑 Stop Loss: %s\n" +
         "🎯 Partial TP 1 (50%%): %s%s (+%.0f pts | +1.0R)\n" +
         "🎯 Final Runner TP: %s%s (+%.0f pts | +1.8R)\n" +
         "═════════════════════════════════\n" +
         "🧠 INSTITUTIONAL REASONS:\n" +
         "• [HTF Trend]: H1 & H4 EMA20 > EMA50 Trend Alignment (+%.1f)\n" +
         "• [SMC Structure]: Market Structure Shift / BOS (+%.1f)\n" +
         "• [Liquidity]: Liquidity Swept in %s Zone (+%.1f)\n" +
         "• [Trigger]: 15m FVG / Order Block Tap + EMA Ribbon (+%.1f)\n" +
         "• [Momentum]: Momentum & RSI Expansion (+%.1f)\n" +
         "• [Volatility Shield]: Parkinson Volatility Stable, Normal Spread (+%.1f)\n" +
         "═════════════════════════════════\n" +
         "🛡️ RISK PLAN:\n" +
         "• SL-Free Execution: Position runs with full breathing room\n" +
         "• Smart Exit: Auto-cut on Confirmed Opposite Signal or target Take Profit\n" +
         "• Max Lot Ceiling: Capped at 0.40 Lots | Scaling on Confirmed Trend Signals",
         symbol,
         dir, icon,
         bd.total_score, grade,
         curr_prefix, DoubleToString(price, dig),
         sl_display,
         curr_prefix, DoubleToString(tp1, dig), tp1_dist_pts,
         curr_prefix, DoubleToString(tp2, dig), tp2_dist_pts,
         bd.score_trend,
         bd.score_structure,
         (dir == "BUY" ? "Discount" : "Premium"), bd.score_liquidity,
         bd.score_fvg_ob,
         bd.score_momentum,
         bd.score_volatility + bd.score_spread
      );
      SendMessage(msg);
     }

   //+---------------------------------------------------------------+
   //| Send Partial TP (50% Banked) & Break-Even Achieved Alert      |
   //+---------------------------------------------------------------+
   void SendPartialTPAchievedAlert(string symbol, ulong ticket, string dir,
                                  double closed_lot, double pct_closed,
                                  double remaining_lot, double be_sl_price, double pnl)
     {
      if(!IsConfigured()) return;
      int dig = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      string msg = StringFormat(
         "🎯 TAKE-PROFIT 1 HIT (50%% BANKED) 🎯\n" +
         "============================\n" +
         "Symbol: %s | Ticket #%d\n" +
         "Closed Volume: %.2f lots (%.0f%%)\n" +
         "Banked Profit: %s$%.2f USD\n" +
         "----------------------------\n" +
         "🛡️ BREAK-EVEN ACTIVATED:\n" +
         "Stop Loss moved to: %s (Risk-Free!)\n" +
         "Remaining Runner: %.2f lots\n" +
         "Runner Trailing at 1.5x ATR\n" +
         "Time: %s",
         symbol, ticket,
         closed_lot, pct_closed,
         (pnl >= 0 ? "+" : ""), pnl,
         DoubleToString(be_sl_price, dig),
         remaining_lot,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)
      );
      SendMessage(msg);
     }

   //+---------------------------------------------------------------+
   //| Send Runner Closed via Trailing Stop or SL Alert              |
   //+---------------------------------------------------------------+
   void SendRunnerClosedAlert(string symbol, ulong ticket, string dir,
                              double exit_price, double pnl, string reason)
     {
      if(!IsConfigured()) return;
      int dig = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      string icon = (pnl >= 0) ? "🏆" : "🛑";
      string msg = StringFormat(
         "%s POSITION CLOSED: %s %s\n" +
         "============================\n" +
         "Symbol: %s | Ticket #%d\n" +
         "Reason: %s\n" +
         "Exit Price: %s\n" +
         "Trade PnL: %s$%.2f USD\n" +
         "Account Balance: $%.2f USD\n" +
         "Time: %s",
         icon, dir, symbol,
         symbol, ticket,
         reason,
         DoubleToString(exit_price, dig),
         (pnl >= 0 ? "+" : ""), pnl,
         AccountInfoDouble(ACCOUNT_BALANCE),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)
      );
      SendMessage(msg);
     }

   //+---------------------------------------------------------------+
   //| Send Standard Trade Execution Alert (Fallback)                |
   //+---------------------------------------------------------------+
   void SendTradeExecutedAlert(string symbol, string dir, double lot, double price,
                               double sl, double tp, double score, int open_pos, int max_pos)
     {
      if(!IsConfigured()) return;
      string icon = (dir == "BUY") ? "⚡🟢" : "⚡🔴";
      double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(pt <= 0.0) pt = 0.01;
      double sl_dist = MathAbs(price - sl) / pt;
      double tp_dist = MathAbs(tp - price) / pt;
      string msg = StringFormat(
         "%s TRADE EXECUTED: %s %s\n" +
         "============================\n" +
         "Lot: %.2f\n" +
         "Entry: %.2f\n" +
         "SL: %.2f (%.0f pts)\n" +
         "TP: %.2f (%.0f pts)\n" +
         "Score: %.0f / 100\n" +
         "Open Positions: %d of %d\n" +
         "Time: %s",
         icon, dir, symbol,
         lot, price,
         sl, sl_dist,
         tp, tp_dist,
         score, open_pos, max_pos,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)
      );
      SendMessage(msg);
     }

   //+---------------------------------------------------------------+
   //| Send Signal Update (Throttle Guarded)                         |
   //+---------------------------------------------------------------+
   void SendSignalUpdate(string symbol, string dir, double price, double score,
                         string regime, string session, double atr, double rr,
                         int open_count, int max_pos, string gate_status)
     {
      if(!IsConfigured()) return;
      if(dir == "HOLD") return;

      datetime now = TimeCurrent();
      if(m_last_signal_dir == dir && (now - m_last_signal_time) < m_signal_throttle_secs)
         return;

      m_last_signal_dir = dir;
      m_last_signal_time = now;

      string icon = (dir == "BUY") ? "🟢" : "🔴";
      string msg = StringFormat(
         "%s KRONOS VIP SIGNAL: %s %s %s\n" +
         "============================\n" +
         "Confidence: %.0f / 100\n" +
         "Price: %.2f\n" +
         "Regime: %s\n" +
         "Session: %s\n" +
         "ATR(14): %.2f\n" +
         "Target R:R: 1:%.1f\n" +
         "Gate: %s\n" +
         "Time: %s",
         icon, dir, symbol, icon,
         score, price, regime, session, atr, rr, gate_status,
         TimeToString(now, TIME_DATE|TIME_SECONDS)
      );
      SendMessage(msg);
     }

   //+---------------------------------------------------------------+
   //| Send Signal Direction Changed Alert                           |
   //+---------------------------------------------------------------+
   void SendDirectionChangeAlert(string symbol, string old_dir, string new_dir, double score, double price)
     {
      if(!IsConfigured()) return;
      if(old_dir == "" || old_dir == new_dir) return;

      string msg = StringFormat(
         "🔄 SIGNAL FLIP: %s -> %s on %s\n" +
         "============================\n" +
         "Score: %.0f / 100\n" +
         "Price: %.2f\n" +
         "Time: %s",
         old_dir, new_dir, symbol, score, price,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)
      );
      SendMessage(msg);
     }

   //+---------------------------------------------------------------+
   //| Send Basket Closed Alert (Legacy Safety)                      |
   //+---------------------------------------------------------------+
   void SendBasketClosedAlert(string symbol, double net_pnl, bool is_tp, int closed_trades)
     {
      if(!IsConfigured()) return;
      string icon = is_tp ? "🎯" : "🛑";
      string msg = StringFormat(
         "%s BASKET CLOSED: %s\n" +
         "Positions: %d\n" +
         "Net PnL: %s$%.2f USD\n" +
         "Balance: $%.2f USD\n" +
         "Time: %s",
         icon, symbol, closed_trades,
         (net_pnl >= 0 ? "+" : ""), net_pnl,
         AccountInfoDouble(ACCOUNT_BALANCE),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)
      );
      SendMessage(msg);
     }
  };
