//+------------------------------------------------------------------+
//|                                       SmartScalper_Filters.mqh   |
//|                                  Copyright 2026, Institutional AI |
//|          Master Entry Quality Filters, Sessions & Anti-Overtrading|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

#include "SmartScalper_Types.mqh"
#include "SmartScalper_Config.mqh"

//+------------------------------------------------------------------+
//| Filters & Safety Engine Class                                    |
//+------------------------------------------------------------------+
class CSmartFilters
  {
private:
   string            m_symbol;
   datetime          m_last_trade_close_time;
   datetime          m_last_loss_close_time;
   datetime          m_last_signal_time;
   string            m_last_signal_dir;
   string            m_last_profit_dir;
   datetime          m_last_profit_time;
   
   int               m_trades_today;
   int               m_losses_today;
   int               m_consecutive_losses;
   datetime          m_current_day_start;
   double            m_initial_day_balance;
   double            m_peak_equity;

   // Rejection Counters
   ulong             m_total_evaluations;
   ulong             m_rej_spread;
   ulong             m_rej_session;
   ulong             m_rej_score;
   ulong             m_rej_ai_conf;
   ulong             m_rej_ai_offline;
   ulong             m_rej_regime;
   ulong             m_rej_rr;
   ulong             m_rej_max_pos;
   ulong             m_rej_cooldown;
   ulong             m_rej_duplicate;
   ulong             m_rej_daily_loss;
   ulong             m_rej_drawdown;
   ulong             m_total_approved;

public:
   CSmartFilters() : m_symbol(""),
                     m_last_trade_close_time(0),
                     m_last_loss_close_time(0),
                     m_last_signal_time(0),
                     m_last_signal_dir(""),
                     m_last_profit_dir(""),
                     m_last_profit_time(0),
                     m_trades_today(0),
                     m_losses_today(0),
                     m_consecutive_losses(0),
                     m_current_day_start(0),
                     m_initial_day_balance(0.0),
                     m_peak_equity(0.0),
                     m_total_evaluations(0),
                     m_rej_spread(0),
                     m_rej_session(0),
                     m_rej_score(0),
                     m_rej_ai_conf(0),
                     m_rej_ai_offline(0),
                     m_rej_regime(0),
                     m_rej_rr(0),
                     m_rej_max_pos(0),
                     m_rej_cooldown(0),
                     m_rej_duplicate(0),
                     m_rej_daily_loss(0),
                     m_rej_drawdown(0),
                     m_total_approved(0)
     {
     }

   void Init(string symbol)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      m_initial_day_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_current_day_start = iTime(m_symbol, PERIOD_D1, 0);
     }

   //+---------------------------------------------------------------+
   //| Refresh Daily Tracking & Peak Equity                          |
   //+---------------------------------------------------------------+
   void RefreshDailyStats()
     {
      datetime today = iTime(m_symbol, PERIOD_D1, 0);
      if(today > m_current_day_start)
        {
         m_current_day_start = today;
         m_trades_today = 0;
         m_losses_today = 0;
         m_initial_day_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        }

      double cur_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(cur_equity > m_peak_equity)
         m_peak_equity = cur_equity;
     }

   //+---------------------------------------------------------------+
   //| Determine Current Market Session Profile                      |
   //+---------------------------------------------------------------+
   ENUM_SESSION_TYPE GetCurrentSession()
     {
      datetime server_time = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(server_time, dt);
      int hour = dt.hour;
      int min  = dt.min;
      int time_mins = hour * 60 + min;

      // London: 07:00 - 15:30 (420 - 930 mins)
      // NY:     13:00 - 21:00 (780 - 1260 mins)
      // Overlap:13:00 - 15:30 (780 - 930 mins)
      // Asian:  00:00 - 08:00 (0 - 480 mins)

      if(time_mins >= 780 && time_mins <= 930)
         return SESSION_OVERLAP;
      if(time_mins >= 420 && time_mins <= 930)
         return SESSION_LONDON;
      if(time_mins >= 780 && time_mins <= 1260)
         return SESSION_NY;
      if(time_mins >= 0 && time_mins <= 480)
         return SESSION_ASIAN;

      return SESSION_CUSTOM;
     }

   //+---------------------------------------------------------------+
   //| Check if Session Profile Permits Trading                      |
   //+---------------------------------------------------------------+
   bool IsSessionPermitted()
     {
      if(InpSessionProfile == PROFILE_ALL_SESSIONS) return true;

      ENUM_SESSION_TYPE current_sess = GetCurrentSession();

      if(InpSessionProfile == PROFILE_LONDON_ONLY)
         return (current_sess == SESSION_LONDON || current_sess == SESSION_OVERLAP);

      if(InpSessionProfile == PROFILE_NY_ONLY)
         return (current_sess == SESSION_NY || current_sess == SESSION_OVERLAP);

      if(InpSessionProfile == PROFILE_LONDON_NY_OVERLAP)
         return (current_sess == SESSION_OVERLAP);

      if(InpSessionProfile == PROFILE_CUSTOM_HOURS)
        {
         datetime cur = TimeCurrent();
         MqlDateTime dt;
         TimeToStruct(cur, dt);
         int cur_min = dt.hour * 60 + dt.min;

         int start_min = ParseTimeMinutes(InpCustomSessionStart);
         int end_min   = ParseTimeMinutes(InpCustomSessionEnd);

         if(start_min <= end_min)
            return (cur_min >= start_min && cur_min <= end_min);
         else // Over midnight
            return (cur_min >= start_min || cur_min <= end_min);
        }

      return true;
     }

   //+---------------------------------------------------------------+
   //| Master Entry Quality Filter Check                             |
   //+---------------------------------------------------------------+
   bool ValidateEntryQuality(bool is_buy,
                             double score,
                             double spread_pts,
                             int open_positions_count,
                             double ai_confidence,
                             bool ai_is_online,
                             string &rejection_reason)
     {
      RefreshDailyStats();
      m_total_evaluations++;

      // 1. Session Filter Check
      if(!IsSessionPermitted())
        {
         m_rej_session++;
         rejection_reason = "SESSION_BLOCK";
         return false;
        }

      // 2. Spread Quality Check
      if(spread_pts > (double)InpMaxSpreadPoints)
        {
         m_rej_spread++;
         rejection_reason = StringFormat("SPREAD_TOO_HIGH (%.1f > %d pts)", spread_pts, InpMaxSpreadPoints);
         return false;
        }

      // 3. Max Open Trades Check (Enforced Minimum 50)
      int max_allowed = MathMax(50, InpMaxOpenTrades);
      if(open_positions_count >= max_allowed)
        {
         m_rej_max_pos++;
         rejection_reason = StringFormat("MAX_POSITIONS_REACHED (%d/%d)", open_positions_count, max_allowed);
         return false;
        }

      // 3b. Pullback Step Check for Basket DCA Scale-in (Method 2)
      if(InpEnableBasketDCA && open_positions_count > 0)
        {
         double last_entry_price = 0.0;
         datetime last_open_time = 0;
         bool has_opposing = false;

         for(int i = PositionsTotal() - 1; i >= 0; i--)
           {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
               continue;

            long pos_type = PositionGetInteger(POSITION_TYPE);
            if((is_buy && pos_type == POSITION_TYPE_BUY) || (!is_buy && pos_type == POSITION_TYPE_SELL))
              {
               datetime o_time = (datetime)PositionGetInteger(POSITION_TIME);
               if(o_time > last_open_time)
                 {
                  last_open_time = o_time;
                  last_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                 }
              }
            else
              {
               has_opposing = true;
              }
           }

         // Block taking opposing trades while a basket is active
         if(has_opposing)
           {
            rejection_reason = "OPPOSING_BASKET_ACTIVE";
            return false;
           }

         // Enforce minimum pullback step distance from last entry
         if(last_entry_price > 0.0)
           {
            double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            if(point <= 0.0) point = 0.01;
            double step_dist = (double)InpGridStepPoints * point;
            double current_price = is_buy ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);

            if(is_buy)
              {
               // For BUY, price must pull down at least step_dist below last entry
               if(current_price > (last_entry_price - step_dist))
                 {
                  double pts_needed = (current_price - (last_entry_price - step_dist)) / point;
                  rejection_reason = StringFormat("WAIT_PULLBACK (Need -%.0f pts drop)", pts_needed);
                  return false;
                 }
              }
            else
              {
               // For SELL, price must pull up at least step_dist above last entry
               if(current_price < (last_entry_price + step_dist))
                 {
                  double pts_needed = ((last_entry_price + step_dist) - current_price) / point;
                  rejection_reason = StringFormat("WAIT_PULLBACK (Need +%.0f pts pump)", pts_needed);
                  return false;
                 }
              }
           }
        }

      // 4. Daily Loss Circuit Breaker
      if(InpMaxDailyLossPct > 0.0 && m_initial_day_balance > 0.0)
        {
         double cur_equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double daily_loss_pct = ((m_initial_day_balance - cur_equity) / m_initial_day_balance) * 100.0;
         if(daily_loss_pct >= InpMaxDailyLossPct)
           {
            m_rej_daily_loss++;
            rejection_reason = StringFormat("DAILY_LOSS_LIMIT (%.2f%% >= %.2f%%)", daily_loss_pct, InpMaxDailyLossPct);
            return false;
           }
        }

      // 5. Total Equity Drawdown Circuit Breaker
      if(InpMaxDrawdownPct > 0.0 && m_peak_equity > 0.0)
        {
         double cur_equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double dd_pct = ((m_peak_equity - cur_equity) / m_peak_equity) * 100.0;
         if(dd_pct >= InpMaxDrawdownPct)
           {
            m_rej_drawdown++;
            rejection_reason = StringFormat("MAX_DRAWDOWN_LIMIT (%.2f%% >= %.2f%%)", dd_pct, InpMaxDrawdownPct);
            return false;
           }
        }

      // 6. Anti-Overtrading: Max Session Trades / Losses
      if(m_trades_today >= InpMaxTradesPerSession)
        {
         m_rej_cooldown++;
         rejection_reason = StringFormat("MAX_TRADES_PER_DAY (%d)", m_trades_today);
         return false;
        }
      if(m_losses_today >= InpMaxLossesPerSession)
        {
         m_rej_cooldown++;
         rejection_reason = StringFormat("MAX_LOSSES_PER_DAY (%d)", m_losses_today);
         return false;
        }

      // 7. Post-Trade & Post-Loss Cooldown Timers
      datetime now = TimeCurrent();
      if(m_last_loss_close_time > 0 && (now - m_last_loss_close_time) < InpCooldownAfterLoss)
        {
         m_rej_cooldown++;
         int remaining = (int)(InpCooldownAfterLoss - (now - m_last_loss_close_time));
         rejection_reason = StringFormat("COOLDOWN_ACTIVE (Post-Loss %ds remaining)", remaining);
         return false;
        }
      if(m_last_trade_close_time > 0 && (now - m_last_trade_close_time) < InpCooldownAfterTrade)
        {
         m_rej_cooldown++;
         int remaining = (int)(InpCooldownAfterTrade - (now - m_last_trade_close_time));
         rejection_reason = StringFormat("COOLDOWN_ACTIVE (Post-Trade %ds remaining)", remaining);
         return false;
        }

      // 8. AI Bridge Gating
      if(InpEnableAIBridge && InpAIRequiredForEntry)
        {
         if(!ai_is_online)
           {
            m_rej_ai_offline++;
            rejection_reason = "AI_BRIDGE_OFFLINE";
            return false;
           }
         if(ai_confidence < InpMinAIConfidence)
           {
            m_rej_ai_conf++;
            rejection_reason = StringFormat("LOW_AI_CONFIDENCE (%.1f%% < %.1f%%)", ai_confidence, InpMinAIConfidence);
            return false;
           }
        }

      // 9. Score Threshold Gating
      if(score < InpScoreThresholdValid)
        {
         m_rej_score++;
         rejection_reason = StringFormat("LOW_SCORE (%.1f < %.1f)", score, InpScoreThresholdValid);
         return false;
        }

      // 10. Duplicate Signal Check
      string current_dir = is_buy ? "BUY" : "SELL";
      if(!InpAllowDuplicateSignals)
        {
         if(m_last_signal_dir == current_dir && (now - m_last_signal_time) < 60)
           {
            m_rej_duplicate++;
            rejection_reason = "DUPLICATE_SIGNAL";
            return false;
           }
        }
      else
        {
         // Allow duplicate signals, but add debounce throttle to avoid multi-execution on the same tick
         if(m_last_signal_dir == current_dir && (now - m_last_signal_time) < MathMax(1, InpDuplicateThrottleSecs))
           {
            rejection_reason = "TICK_DEBOUNCE";
            return false;
           }
        }

      m_total_approved++;
      rejection_reason = "APPROVED";
      return true;
     }

   void RecordRegimeRejection() { m_total_evaluations++; m_rej_regime++; }
   void RecordRRRejection()     { m_total_evaluations++; m_rej_rr++; }

   //+---------------------------------------------------------------+
   //| Print Full Rejection Breakdown Report                         |
   //+---------------------------------------------------------------+
   void PrintRejectionBreakdown()
     {
      Print("=================================================================");
      Print("📊 [SMARTSCALPER V2] REJECTION BREAKDOWN & QUALITY AUDIT");
      Print("=================================================================");
      PrintFormat("Total Setups Evaluated: %d", m_total_evaluations);
      PrintFormat("Total Setups Approved : %d (%.1f%%)", m_total_approved, (m_total_evaluations > 0 ? (double)m_total_approved / m_total_evaluations * 100.0 : 0.0));
      Print("-----------------------------------------------------------------");
      PrintFormat("  LOW_SCORE              : %d (%.1f%%)", m_rej_score, (m_total_evaluations > 0 ? (double)m_rej_score / m_total_evaluations * 100.0 : 0.0));
      PrintFormat("  BAD_REGIME             : %d (%.1f%%)", m_rej_regime, (m_total_evaluations > 0 ? (double)m_rej_regime / m_total_evaluations * 100.0 : 0.0));
      PrintFormat("  BAD_RR                 : %d (%.1f%%)", m_rej_rr, (m_total_evaluations > 0 ? (double)m_rej_rr / m_total_evaluations * 100.0 : 0.0));
      PrintFormat("  SESSION_BLOCK          : %d (%.1f%%)", m_rej_session, (m_total_evaluations > 0 ? (double)m_rej_session / m_total_evaluations * 100.0 : 0.0));
      PrintFormat("  SPREAD_TOO_HIGH        : %d (%.1f%%)", m_rej_spread, (m_total_evaluations > 0 ? (double)m_rej_spread / m_total_evaluations * 100.0 : 0.0));
      PrintFormat("  MAX_POSITIONS_REACHED  : %d (%.1f%%)", m_rej_max_pos, (m_total_evaluations > 0 ? (double)m_rej_max_pos / m_total_evaluations * 100.0 : 0.0));
      PrintFormat("  COOLDOWN_ACTIVE        : %d (%.1f%%)", m_rej_cooldown, (m_total_evaluations > 0 ? (double)m_rej_cooldown / m_total_evaluations * 100.0 : 0.0));
      PrintFormat("  DUPLICATE_SIGNAL       : %d (%.1f%%)", m_rej_duplicate, (m_total_evaluations > 0 ? (double)m_rej_duplicate / m_total_evaluations * 100.0 : 0.0));
      PrintFormat("  DAILY_LOSS_LIMIT       : %d (%.1f%%)", m_rej_daily_loss, (m_total_evaluations > 0 ? (double)m_rej_daily_loss / m_total_evaluations * 100.0 : 0.0));
      PrintFormat("  MAX_DRAWDOWN_LIMIT     : %d (%.1f%%)", m_rej_drawdown, (m_total_evaluations > 0 ? (double)m_rej_drawdown / m_total_evaluations * 100.0 : 0.0));
      PrintFormat("  LOW_AI_CONFIDENCE      : %d (%.1f%%)", m_rej_ai_conf, (m_total_evaluations > 0 ? (double)m_rej_ai_conf / m_total_evaluations * 100.0 : 0.0));
      PrintFormat("  AI_BRIDGE_OFFLINE      : %d (%.1f%%)", m_rej_ai_offline, (m_total_evaluations > 0 ? (double)m_rej_ai_offline / m_total_evaluations * 100.0 : 0.0));
      Print("=================================================================");
     }

   //+---------------------------------------------------------------+
   //| Record Executed Trade                                         |
   //+---------------------------------------------------------------+
   void OnTradeExecuted(string direction)
     {
      m_last_signal_time = TimeCurrent();
      m_last_signal_dir = direction;
      m_trades_today++;
     }

   //+---------------------------------------------------------------+
   //| Record Closed Trade Result                                    |
   //+---------------------------------------------------------------+
   void OnTradeClosed(bool is_profit)
     {
      m_last_trade_close_time = TimeCurrent();
      if(!is_profit)
        {
         m_last_loss_close_time = TimeCurrent();
         m_losses_today++;
         m_consecutive_losses++;
        }
      else
        {
         m_consecutive_losses = 0;
         m_last_profit_dir = m_last_signal_dir;
         m_last_profit_time = TimeCurrent();
        }
     }

   // Helpers
   int GetTradesToday()        { return m_trades_today; }
   int GetLossesToday()        { return m_losses_today; }
   int GetConsecutiveLosses()  { return m_consecutive_losses; }
   string GetLastProfitDir()   { return m_last_profit_dir; }
   datetime GetLastProfitTime(){ return m_last_profit_time; }
   bool IsRecentProfitDirection(string dir, int max_seconds)
     {
      if(m_last_profit_dir == dir && m_last_profit_time > 0 && (TimeCurrent() - m_last_profit_time) <= max_seconds)
         return true;
      return false;
     }

private:
   int ParseTimeMinutes(string time_str)
     {
      string parts[];
      if(StringSplit(time_str, ':', parts) >= 2)
        {
         return (int)StringToInteger(parts[0]) * 60 + (int)StringToInteger(parts[1]);
        }
      return 0;
     }
  };
