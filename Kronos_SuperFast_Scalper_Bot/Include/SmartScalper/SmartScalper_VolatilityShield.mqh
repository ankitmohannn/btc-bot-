//+------------------------------------------------------------------+
//|                                SmartScalper_VolatilityShield.mqh |
//|                                  Copyright 2026, Institutional AI |
//|     Institutional Volatility Clustering & Tail-Risk Position Sizer|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.10"
#property strict

#include "SmartScalper_Types.mqh"

//+------------------------------------------------------------------+
//| Volatility Regime Classification Enumeration                     |
//+------------------------------------------------------------------+
enum ENUM_VOLATILITY_REGIME
  {
   VOL_REGIME_LOW      = 0,  // Compression / Low Volatility (Safe, but slower expansion)
   VOL_REGIME_NORMAL   = 1,  // Normal Volatility Regime (Standard calculated risk)
   VOL_REGIME_HIGH     = 2,  // High Volatility Expansion (Scale down exposure)
   VOL_REGIME_EXTREME  = 3   // Extreme Shock / Tail-Risk Spike (Severe scale down or BLOCK)
  };

//+------------------------------------------------------------------+
//| Volatility Shield Assessment Result Structure                    |
//+------------------------------------------------------------------+
struct MqlVolShieldAssessment
  {
   ENUM_VOLATILITY_REGIME vol_regime;
   double                 parkinson_vol;
   double                 atr_fast;
   double                 atr_slow;
   double                 vol_clustering_ratio; // Fast ATR / Slow ATR
   double                 kurtosis;             // Fat-tail measurement
   double                 skewness;             // Asymmetry / Crash bias
   double                 var_99_pct;           // Cornish-Fisher 99% VaR (%)
   double                 tail_risk_score;      // 0.0 - 100.0 Tail Risk Index
   double                 signal_confidence;    // Input Signal Confidence (0-100%)
   double                 original_lot;         // Pre-adjustment lot size
   double                 adjusted_lot;         // Volatility & Tail-Risk adjusted lot
   double                 risk_multiplier;      // Sizing multiplier applied (0.0 to 1.0)
   bool                   is_trade_allowed;     // Safety Gate Approval
   string                 decision_reason;      // Explainable audit reason
   datetime               assessment_time;
  };

//+------------------------------------------------------------------+
//| Volatility Clustering & Tail-Risk Position Sizing Engine Class   |
//+------------------------------------------------------------------+
class CSmartVolatilityShield
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   bool              m_is_gold;
   bool              m_is_crypto;

   // Configuration Thresholds
   bool              m_enabled;
   int               m_fast_period;
   int               m_slow_period;
   int               m_tail_lookback;
   double            m_high_vol_ratio;
   double            m_extreme_vol_ratio;
   double            m_tail_risk_block_threshold;
   bool              m_block_extreme_vol;
   double            m_max_symbol_exposure_lots;

public:
   CSmartVolatilityShield() :
      m_symbol(""),
      m_timeframe(PERIOD_M5),
      m_is_gold(false),
      m_is_crypto(false),
      m_enabled(true),
      m_fast_period(5),
      m_slow_period(50),
      m_tail_lookback(60),
      m_high_vol_ratio(1.35),
      m_extreme_vol_ratio(2.10),
      m_tail_risk_block_threshold(85.0),
      m_block_extreme_vol(false),
      m_max_symbol_exposure_lots(5.0)
     {}

   //+---------------------------------------------------------------+
   //| Initialization & Asset Adaptation                             |
   //+---------------------------------------------------------------+
   void Init(string symbol, ENUM_TIMEFRAMES tf=PERIOD_M5)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      m_timeframe = tf;

      string sym_upper = m_symbol;
      StringToUpper(sym_upper);

      m_is_gold   = (StringFind(sym_upper, "XAU") >= 0 || StringFind(sym_upper, "GOLD") >= 0);
      m_is_crypto = (StringFind(sym_upper, "BTC") >= 0 || StringFind(sym_upper, "ETH") >= 0 || StringFind(sym_upper, "CRYPTO") >= 0);

      // Asset-Specific Parameter Tuning (Gold vs Crypto vs FX)
      if(m_is_gold)
        {
         m_high_vol_ratio    = 1.30;
         m_extreme_vol_ratio = 2.00;
         m_max_symbol_exposure_lots = 2.00;
        }
      else if(m_is_crypto)
        {
         m_high_vol_ratio    = 1.40;
         m_extreme_vol_ratio = 2.25;
         m_max_symbol_exposure_lots = 3.00;
        }
      else // Standard FX / Indices
        {
         m_high_vol_ratio    = 1.35;
         m_extreme_vol_ratio = 2.10;
         m_max_symbol_exposure_lots = 5.00;
        }

      PrintFormat("🛡️ [VOL_SHIELD_INIT] Symbol: %s | Asset: %s | HighVolRatio: %.2f | ExtremeVolRatio: %.2f | Lookback: %d",
                  m_symbol, (m_is_gold ? "GOLD (XAU)" : (m_is_crypto ? "CRYPTO (BTC)" : "STANDARD")),
                  m_high_vol_ratio, m_extreme_vol_ratio, m_tail_lookback);
     }

   // Setters for external EA input configuration
   void Configure(bool enabled, int fast_p, int slow_p, int tail_lb, double high_ratio, double extreme_ratio, double tail_block, bool block_extreme, double max_exp)
     {
      m_enabled                   = enabled;
      m_fast_period               = MathMax(3, fast_p);
      m_slow_period               = MathMax(m_fast_period + 5, slow_p);
      m_tail_lookback             = MathMax(20, tail_lb);
      m_high_vol_ratio            = high_ratio;
      m_extreme_vol_ratio         = extreme_ratio;
      m_tail_risk_block_threshold = tail_block;
      m_block_extreme_vol         = block_extreme;
      m_max_symbol_exposure_lots  = max_exp;
     }

   //+---------------------------------------------------------------+
   //| Parkinson High-Low Volatility Estimator (Zero Look-Ahead)     |
   //+---------------------------------------------------------------+
   double CalculateParkinsonVol(int period, int shift=1)
     {
      if(period <= 0) return 0.0;
      double sum_sq_ln = 0.0;
      int count = 0;

      for(int i = shift; i < shift + period; i++)
        {
         double high = iHigh(m_symbol, m_timeframe, i);
         double low  = iLow(m_symbol, m_timeframe, i);
         if(high > 0.0 && low > 0.0 && high >= low)
           {
            double ratio = high / low;
            if(ratio > 1.0)
              {
               double ln_val = MathLog(ratio);
               sum_sq_ln += (ln_val * ln_val);
               count++;
              }
           }
        }
      if(count < (period / 2) || count == 0) return 0.0;
      double factor = 1.0 / (4.0 * MathLog(2.0) * (double)count);
      return MathSqrt(factor * sum_sq_ln);
     }

   //+---------------------------------------------------------------+
   //| Simple ATR Calculation on Closed Bars                         |
   //+---------------------------------------------------------------+
   double CalculateClosedATR(int period, int shift=1)
     {
      if(period <= 0) return 0.0;
      double sum_tr = 0.0;
      int count = 0;

      for(int i = shift; i < shift + period; i++)
        {
         double high  = iHigh(m_symbol, m_timeframe, i);
         double low   = iLow(m_symbol, m_timeframe, i);
         double close = iClose(m_symbol, m_timeframe, i + 1);

         if(high <= 0.0 || low <= 0.0 || close <= 0.0) continue;
         double tr = MathMax(high - low, MathMax(MathAbs(high - close), MathAbs(low - close)));
         sum_tr += tr;
         count++;
        }
      return (count > 0) ? (sum_tr / (double)count) : 0.0;
     }

   //+---------------------------------------------------------------+
   //| Higher-Order Moments & Cornish-Fisher Tail-Risk VaR 99%       |
   //+---------------------------------------------------------------+
   void CalculateTailRiskMetrics(int lookback, double &kurtosis, double &skewness, double &var_99, double &tail_score, int shift=1)
     {
      kurtosis   = 3.0; // Normal distribution baseline
      skewness   = 0.0;
      var_99     = 0.0;
      tail_score = 50.0;

      if(lookback < 20) return;

      double returns[];
      ArrayResize(returns, lookback);
      double sum_ret = 0.0;
      int valid_bars = 0;

      for(int i = 0; i < lookback; i++)
        {
         int bar_idx = shift + i;
         double p_cur  = iClose(m_symbol, m_timeframe, bar_idx);
         double p_prev = iClose(m_symbol, m_timeframe, bar_idx + 1);

         if(p_cur > 0.0 && p_prev > 0.0)
           {
            double r = MathLog(p_cur / p_prev);
            returns[valid_bars] = r;
            sum_ret += r;
            valid_bars++;
           }
        }

      if(valid_bars < 20) return;

      double mean = sum_ret / (double)valid_bars;
      double m2 = 0.0;
      double m3 = 0.0;
      double m4 = 0.0;

      for(int i = 0; i < valid_bars; i++)
        {
         double diff = returns[i] - mean;
         double diff2 = diff * diff;
         double diff3 = diff2 * diff;
         double diff4 = diff3 * diff;

         m2 += diff2;
         m3 += diff3;
         m4 += diff4;
        }

      double variance = m2 / (double)(valid_bars - 1);
      double std_dev  = MathSqrt(MathMax(1e-12, variance));

      if(std_dev > 1e-9)
        {
         skewness = (m3 / (double)valid_bars) / MathPow(std_dev, 3.0);
         kurtosis = (m4 / (double)valid_bars) / MathPow(std_dev, 4.0); // Full Kurtosis
        }

      // Excess Kurtosis
      double excess_kurt = kurtosis - 3.0;

      // Cornish-Fisher expansion for alpha = 0.01 (z_alpha = 2.3263)
      double z_alpha = 2.326348;
      double z_cf = z_alpha
                    + (MathPow(z_alpha, 2.0) - 1.0) * (skewness / 6.0)
                    + (MathPow(z_alpha, 3.0) - 3.0 * z_alpha) * (excess_kurt / 24.0)
                    - (2.0 * MathPow(z_alpha, 3.0) - 5.0 * z_alpha) * (MathPow(skewness, 2.0) / 36.0);

      var_99 = (mean - (z_cf * std_dev)) * 100.0; // In percentage

      // Normalize Tail-Risk Score to 0-100 scale
      // Score increases with fat tails (Kurtosis > 3.0) and negative crash skew
      double raw_score = 50.0;
      raw_score += (excess_kurt * 4.5);
      raw_score += (-skewness * 12.0); // Negative skewness (crash risk) increases score
      raw_score += (MathAbs(var_99) * 10.0);

      tail_score = MathMin(100.0, MathMax(0.0, raw_score));
     }

   //+---------------------------------------------------------------+
   //| Master Volatility & Tail-Risk Position Sizing Assessment      |
   //+---------------------------------------------------------------+
   void AssessVolatilityAndTailRisk(double candidate_lot, double signal_conf, MqlVolShieldAssessment &out)
     {
      out.assessment_time    = TimeCurrent();
      out.original_lot       = candidate_lot;
      out.signal_confidence  = signal_conf;
      out.is_trade_allowed   = true;
      out.decision_reason    = "Normal Calculated Risk";
      out.risk_multiplier    = 1.0;

      if(!m_enabled)
        {
         out.vol_regime   = VOL_REGIME_NORMAL;
         out.adjusted_lot = candidate_lot;
         out.decision_reason = "Volatility Shield Disabled by Config";
         return;
        }

      // 1. Calculate Volatility Metrics (Zero Look-Ahead)
      out.atr_fast      = CalculateClosedATR(m_fast_period, 1);
      out.atr_slow      = CalculateClosedATR(m_slow_period, 1);
      out.parkinson_vol = CalculateParkinsonVol(m_fast_period, 1);

      if(out.atr_slow > 0.0)
         out.vol_clustering_ratio = out.atr_fast / out.atr_slow;
      else
         out.vol_clustering_ratio = 1.0;

      // 2. Calculate Tail-Risk & Cornish-Fisher VaR 99%
      CalculateTailRiskMetrics(m_tail_lookback, out.kurtosis, out.skewness, out.var_99_pct, out.tail_risk_score, 1);

      // 3. Classify Volatility Regime
      if(out.vol_clustering_ratio > m_extreme_vol_ratio)
        {
         out.vol_regime = VOL_REGIME_EXTREME;
        }
      else if(out.vol_clustering_ratio > m_high_vol_ratio)
        {
         out.vol_regime = VOL_REGIME_HIGH;
        }
      else if(out.vol_clustering_ratio < 0.70)
        {
         out.vol_regime = VOL_REGIME_LOW;
        }
      else
        {
         out.vol_regime = VOL_REGIME_NORMAL;
        }

      // 4. Calculate Risk Multiplier Matrix
      double vol_mult = 1.0;

      switch(out.vol_regime)
        {
         case VOL_REGIME_LOW:
            vol_mult = 0.85; // Low volatility compression (moderate sizing)
            out.decision_reason = "Low Volatility Compression Dampener";
            break;

         case VOL_REGIME_NORMAL:
            vol_mult = 1.00; // Full standard risk
            out.decision_reason = "Normal Volatility Regime";
            break;

         case VOL_REGIME_HIGH:
            vol_mult = 0.50; // Reduce position size by 50% during volatility expansion
            out.decision_reason = "High Volatility Expansion Sizing Dampener (0.50x)";
            break;

         case VOL_REGIME_EXTREME:
            if(m_block_extreme_vol)
              {
               vol_mult = 0.0;
               out.is_trade_allowed = false;
               out.decision_reason = "BLOCKED: Extreme Volatility Shock (Ratio > " + DoubleToString(m_extreme_vol_ratio, 2) + ")";
              }
            else
              {
               vol_mult = 0.20; // Drastically reduce exposure by 80% during extreme volatility
               out.decision_reason = "Extreme Volatility Regime: Defensive Sizing (0.20x)";
              }
            break;
        }

      // 5. Apply Tail-Risk Dampening
      double tail_mult = 1.0;
      if(out.tail_risk_score >= m_tail_risk_block_threshold)
        {
         if(out.vol_regime == VOL_REGIME_HIGH || out.vol_regime == VOL_REGIME_EXTREME)
           {
            out.is_trade_allowed = false;
            out.decision_reason = StringFormat("BLOCKED: Severe Tail-Risk Confluence (Score: %.1f | Kurt: %.1f | VaR99: %.2f%%)",
                                               out.tail_risk_score, out.kurtosis, out.var_99_pct);
            vol_mult = 0.0;
           }
         else
           {
            tail_mult = 0.40;
            out.decision_reason += StringFormat(" + Elevated Tail Risk (Score: %.1f)", out.tail_risk_score);
           }
        }
      else if(out.tail_risk_score >= 70.0)
        {
         tail_mult = 0.70;
         out.decision_reason += StringFormat(" + Moderate Tail Risk (Score: %.1f)", out.tail_risk_score);
        }

      // 6. Signal Confidence Multiplier Scaling
      double conf_factor = MathMin(1.10, MathMax(0.70, signal_conf / 80.0));

      // 7. Combined Multiplier & Adjusted Lot Calculation
      out.risk_multiplier = vol_mult * tail_mult * conf_factor;
      if(!out.is_trade_allowed) out.risk_multiplier = 0.0;

      double min_lot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double max_lot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double step_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

      if(min_lot <= 0.0)  min_lot = 0.01;
      if(max_lot <= 0.0)  max_lot = 100.0;
      if(step_lot <= 0.0) step_lot = 0.01;

      double raw_adjusted = candidate_lot * out.risk_multiplier;

      if(raw_adjusted < min_lot && out.is_trade_allowed && out.risk_multiplier > 0.0)
         raw_adjusted = min_lot;

      // Floor to volume step
      double normalized_lot = MathFloor(raw_adjusted / step_lot) * step_lot;

      if(normalized_lot < min_lot && out.is_trade_allowed) normalized_lot = min_lot;
      if(normalized_lot > m_max_symbol_exposure_lots) normalized_lot = m_max_symbol_exposure_lots;
      if(normalized_lot > InpMaxLot) normalized_lot = InpMaxLot;
      if(normalized_lot > 0.40) normalized_lot = 0.40;

      int lot_digits = 2;
      if(step_lot == 0.1)  lot_digits = 1;
      if(step_lot == 1.0)  lot_digits = 0;
      if(step_lot == 0.001) lot_digits = 3;

      out.adjusted_lot = NormalizeDouble(normalized_lot, lot_digits);
     }

   //+---------------------------------------------------------------+
   //| Formatted Audit Logging                                       |
   //+---------------------------------------------------------------+
   void LogAssessment(const MqlVolShieldAssessment &a)
     {
      string reg_str = "NORMAL";
      if(a.vol_regime == VOL_REGIME_LOW) reg_str = "LOW";
      else if(a.vol_regime == VOL_REGIME_HIGH) reg_str = "HIGH";
      else if(a.vol_regime == VOL_REGIME_EXTREME) reg_str = "EXTREME";

      PrintFormat("🛡️ [VOLATILITY SHIELD AUDIT] Symbol: %s | Regime: %s | Ratio: %.2f (Fast: %.2f / Slow: %.2f) | ParkVol: %.4f | Kurt: %.2f | Skew: %.2f | VaR99: %.2f%% | TailScore: %.1f | Conf: %.1f%% | Lot: %.2f -> %.2f (x%.2f) | %s | Allowed: %s",
                  m_symbol, reg_str, a.vol_clustering_ratio, a.atr_fast, a.atr_slow, a.parkinson_vol,
                  a.kurtosis, a.skewness, a.var_99_pct, a.tail_risk_score, a.signal_confidence,
                  a.original_lot, a.adjusted_lot, a.risk_multiplier,
                  a.decision_reason, (a.is_trade_allowed ? "YES" : "NO"));
     }
  };
//+------------------------------------------------------------------+
