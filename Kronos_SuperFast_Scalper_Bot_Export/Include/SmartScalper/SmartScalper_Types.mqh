//+------------------------------------------------------------------+
//|                                           SmartScalper_Types.mqh |
//|                                  Copyright 2026, Institutional AI |
//|                             Type Definitions for SmartScalper V2 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| Market Regime Enumeration                                        |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
  {
   REGIME_NO_TRADE          = 0,  // No Trade / Inactive / Restricted
   REGIME_TRENDING_UP       = 1,  // Strong Bullish Trend
   REGIME_TRENDING_DOWN     = 2,  // Strong Bearish Trend
   REGIME_RANGE             = 3,  // Range-bound / Mean Reversion
   REGIME_HIGH_VOLATILITY   = 4,  // High Volatility Expansion
   REGIME_LOW_VOLATILITY    = 5,  // Low Volatility Contraction / Compression
   REGIME_BREAKOUT          = 6,  // Bullish Volatility Breakout
   REGIME_BREAKDOWN         = 7,  // Bearish Volatility Breakdown
   REGIME_REVERSAL          = 8,  // Potential Macro/Structural Reversal
   REGIME_NEWS_RISK         = 9,  // High Impact News Risk / High Spread
   REGIME_LIQUIDITY_EVENT   = 10  // Major Liquidity Sweep in progress
  };

//+------------------------------------------------------------------+
//| Signal State Classification                                      |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_STATE
  {
   SIGNAL_NO_TRADE = 0, // Score 0 - 59: No Trade Setup
   SIGNAL_WEAK     = 1, // Score 60 - 69: Weak / Monitor Only
   SIGNAL_VALID    = 2, // Score 70 - 79: Valid Trade Setup
   SIGNAL_STRONG   = 3, // Score 80 - 89: Strong Institutional Setup
   SIGNAL_EXTREME  = 4  // Score 90 - 100: Extreme High Probability
  };

//+------------------------------------------------------------------+
//| Market Session Profile                                           |
//+------------------------------------------------------------------+
enum ENUM_SESSION_TYPE
  {
   SESSION_CLOSED   = 0, // Market Session Inactive
   SESSION_ASIAN    = 1, // Asian Session (Tokyo/Sydney)
   SESSION_LONDON   = 2, // London European Session
   SESSION_NY       = 3, // New York North American Session
   SESSION_OVERLAP  = 4, // London / New York Overlap (Peak Liquidity)
   SESSION_CUSTOM   = 5  // User-Defined Custom Hours
  };

//+------------------------------------------------------------------+
//| Session Filter Selection Configuration                           |
//+------------------------------------------------------------------+
enum ENUM_SESSION_PROFILE_SELECT
  {
   PROFILE_ALL_SESSIONS      = 0, // Trade All Sessions (24/5)
   PROFILE_LONDON_ONLY       = 1, // London Session Only
   PROFILE_NY_ONLY           = 2, // New York Session Only
   PROFILE_LONDON_NY_OVERLAP = 3, // London + NY Overlap Peak
   PROFILE_CUSTOM_HOURS      = 4  // Use Custom Server Hours
  };

//+------------------------------------------------------------------+
//| Stop Loss Calculation Mode                                       |
//+------------------------------------------------------------------+
enum ENUM_SL_MODE
  {
   SL_MODE_STRUCTURAL       = 0, // Structural Swing Low/High Invalidation
   SL_MODE_ATR              = 1, // Dynamic ATR Volatility Multiple
   SL_MODE_HYBRID_SAFE      = 2, // Safest of Structural and ATR distance
   SL_MODE_OPPOSITE_SIGNAL  = 3  // Exit on Opposite Signal Reversal (No tight broker SL)
  };

//+------------------------------------------------------------------+
//| Take Profit Calculation Mode                                     |
//+------------------------------------------------------------------+
enum ENUM_TP_MODE
  {
   TP_MODE_FIXED_RR     = 0, // Fixed Risk-to-Reward Ratio Target
   TP_MODE_LIQUIDITY_OB = 1, // Opposing Liquidity Pool / Order Block
   TP_MODE_HYBRID       = 2  // Liquidity Target with Minimum RR Floor
  };

//+------------------------------------------------------------------+
//| Market Structure Event Type                                      |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE_EVENT
  {
   STRUCT_NONE          = 0,
   STRUCT_BOS_BULL      = 1, // Bullish Break of Structure
   STRUCT_BOS_BEAR      = 2, // Bearish Break of Structure
   STRUCT_CHOCH_BULL    = 3, // Bullish Change of Character
   STRUCT_CHOCH_BEAR    = 4, // Bearish Change of Character
   STRUCT_SWEEP_BSL     = 5, // Buy-Side Liquidity Swept (Bearish Indication)
   STRUCT_SWEEP_SSL     = 6  // Sell-Side Liquidity Swept (Bullish Indication)
  };

//+------------------------------------------------------------------+
//| Fair Value Gap (FVG) Struct                                      |
//+------------------------------------------------------------------+
struct MqlFairValueGap
  {
   datetime          time;          // Timestamp of the FVG creation candle (bar 1)
   int               bar_index;     // Bar index
   bool              is_bullish;    // True = Bullish (Gap up), False = Bearish (Gap down)
   double            top_price;     // Top boundary of gap
   double            bottom_price;  // Bottom boundary of gap
   double            mid_price;     // 50% Consequent Encroachment
   bool              is_mitigated;  // Has price filled this gap?
   datetime          mitigation_time;
  };

//+------------------------------------------------------------------+
//| Order Block (OB) Struct                                          |
//+------------------------------------------------------------------+
struct MqlOrderBlock
  {
   datetime          time;          // Timestamp of the OB candle
   int               bar_index;     // Bar index
   bool              is_bullish;    // True = Demand / Bullish OB, False = Supply / Bearish OB
   double            high_price;    // Candle High
   double            low_price;     // Candle Low
   double            open_price;    // Candle Open
   double            close_price;   // Candle Close
   bool              is_mitigated;  // Has price tested this OB?
   int               strength;      // Displacement strength rating (1-5)
  };

//+------------------------------------------------------------------+
//| Swing Point Struct                                               |
//+------------------------------------------------------------------+
struct MqlSwingPoint
  {
   datetime          time;          // Timestamp of the swing peak/trough
   int               bar_index;     // Bar index where swing occurred
   double            price;         // Price level of the swing
   bool              is_high;       // True = Swing High, False = Swing Low
   bool              is_major;      // True = Major Swing, False = Minor/Internal
   bool              is_swept;      // Has liquidity above/below been swept?
  };

//+------------------------------------------------------------------+
//| Multi-Timeframe Status Struct                                    |
//+------------------------------------------------------------------+
struct MqlMTFState
  {
   ENUM_TIMEFRAMES   timeframe;
   int               trend_direction; // +1 Bullish, -1 Bearish, 0 Neutral
   double            ema9;
   double            ema20;
   double            ema50;
   double            ema200;
   double            rsi;
   double            adx;
   double            atr;
   ENUM_STRUCTURE_EVENT last_structure_event;
   datetime          last_event_time;
   double            score_contribution; // Score contribution for this TF
  };

//+------------------------------------------------------------------+
//| Score Breakdown Details                                          |
//+------------------------------------------------------------------+
struct MqlScoreBreakdown
  {
   double            total_score;      // 0.0 - 100.0
   double            score_trend;      // Max 15.0
   double            score_structure;  // Max 15.0
   double            score_liquidity;  // Max 15.0
   double            score_momentum;   // Max 10.0
   double            score_volatility; // Max 10.0
   double            score_fvg_ob;     // Max 10.0
   double            score_mtf;        // Max 10.0
   double            score_spread;     // Max 5.0
   double            score_session;    // Max 5.0
   double            score_ai;         // Max 5.0
   double            score_booster;    // Trend Continuation Booster (Max InpTrendBoosterScore)
   string            direction;        // "BUY", "SELL", or "HOLD"
   string            explanation;      // Formatted summary explanation
  };

//+------------------------------------------------------------------+
//| AI Bridge Signal Packet Struct                                   |
//+------------------------------------------------------------------+
struct MqlAISignalPacket
  {
   string            symbol;
   string            direction;        // "BUY", "SELL", "HOLD"
   double            confidence;       // 0.0 - 100.0%
   ENUM_MARKET_REGIME regime;
   double            expected_move;    // Expected price displacement
   double            risk_score;       // 0.0 - 100.0 (lower is safer)
   int               valid_for_seconds;// TTL in seconds (e.g. 30s)
   datetime          generated_time;   // Local or UTC timestamp
   string            reason_codes;     // Comma-separated rationale tags
   bool              is_valid;         // True if packet parsed and not expired
  };

//+------------------------------------------------------------------+
//| Feature Packet Sent to AI Bridge                                 |
//+------------------------------------------------------------------+
struct MqlFeaturePacket
  {
   string            symbol;
   datetime          timestamp;
   double            bid;
   double            ask;
   double            spread_points;
   int               timeframe_seconds;
   double            open;
   double            high;
   double            low;
   double            close;
   long              tick_volume;
   double            atr_m5;
   double            rsi_m5;
   double            adx_m5;
   double            ema9_m5;
   double            ema20_m5;
   double            ema50_m5;
   double            ema200_m5;
   int               regime_id;
   int               structure_id;
   int               session_id;
   double            recent_win_rate;
   int               consecutive_losses;
  };

//+------------------------------------------------------------------+
//| Trade Journal Record Struct                                      |
//+------------------------------------------------------------------+
struct MqlTradeJournalRecord
  {
   ulong             ticket;
   datetime          open_time;
   datetime          close_time;
   string            symbol;
   string            direction;
   double            open_price;
   double            close_price;
   double            sl_price;
   double            tp_price;
   double            lot_size;
   double            profit_usd;
   double            profit_pips;
   double            commission;
   double            swap;
   double            entry_spread;
   double            entry_atr;
   string            regime_name;
   double            deterministic_score;
   double            ai_confidence;
   string            reason_codes;
   string            session_name;
   double            mae_points;       // Maximum Adverse Excursion
   double            mfe_points;       // Maximum Favorable Excursion
   int               duration_seconds;
   string            exit_reason;      // "TP", "SL", "BE", "TRAIL", "TIME", "MANUAL"
  };

//+------------------------------------------------------------------+
//| Helper Function: Convert Regime Enum to String                   |
//+------------------------------------------------------------------+
string RegimeToString(ENUM_MARKET_REGIME regime)
  {
   switch(regime)
     {
      case REGIME_TRENDING_UP:     return "TRENDING_UP";
      case REGIME_TRENDING_DOWN:   return "TRENDING_DOWN";
      case REGIME_RANGE:           return "RANGE";
      case REGIME_HIGH_VOLATILITY: return "HIGH_VOLATILITY";
      case REGIME_LOW_VOLATILITY:  return "LOW_VOLATILITY";
      case REGIME_BREAKOUT:        return "BREAKOUT";
      case REGIME_BREAKDOWN:       return "BREAKDOWN";
      case REGIME_REVERSAL:        return "REVERSAL";
      case REGIME_NEWS_RISK:       return "NEWS_RISK";
      case REGIME_LIQUIDITY_EVENT: return "LIQUIDITY_EVENT";
      default:                     return "NO_TRADE";
     }
  }

//+------------------------------------------------------------------+
//| Helper Function: Convert Signal State to String                  |
//+------------------------------------------------------------------+
string SignalStateToString(ENUM_SIGNAL_STATE state)
  {
   switch(state)
     {
      case SIGNAL_WEAK:    return "WEAK";
      case SIGNAL_VALID:   return "VALID";
      case SIGNAL_STRONG:  return "STRONG";
      case SIGNAL_EXTREME: return "EXTREME";
      default:             return "NO_TRADE";
     }
  }

//+------------------------------------------------------------------+
//| Helper Function: Convert Session Type to String                  |
//+------------------------------------------------------------------+
string SessionToString(ENUM_SESSION_TYPE session)
  {
   switch(session)
     {
      case SESSION_ASIAN:   return "ASIA";
      case SESSION_LONDON:  return "LONDON";
      case SESSION_NY:      return "NEW_YORK";
      case SESSION_OVERLAP: return "LON_NY_OVERLAP";
      case SESSION_CUSTOM:  return "CUSTOM_HOURS";
      default:              return "CLOSED";
     }
  }
