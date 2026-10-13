//+------------------------------------------------------------------+
//|                                         SmartScalper_Scoring.mqh |
//|                                  Copyright 2026, Institutional AI |
//|                0-100 Explainable Scoring & Signal Synthesis Engine |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

#include "SmartScalper_Types.mqh"
#include "SmartScalper_Config.mqh"
#include "SmartScalper_FeatureEngine.mqh"
#include "SmartScalper_SMC.mqh"
#include "SmartScalper_MTF.mqh"
#include "SmartScalper_Regime.mqh"

//+------------------------------------------------------------------+
//| Signal Scoring Engine Class                                      |
//+------------------------------------------------------------------+
class CSmartScoringEngine
  {
private:
   string m_symbol;

public:
   CSmartScoringEngine() : m_symbol("") {}

   void Init(string symbol)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
     }

   //+---------------------------------------------------------------+
   //| Calculate 0-100 Score Breakdown for a Candidate Direction     |
   //+---------------------------------------------------------------+
   void EvaluateSignal(bool is_buy,
                       CSmartFeatureEngine &engine,
                       CSmartSMC &smc,
                       CSmartMTF &mtf,
                       ENUM_MARKET_REGIME regime,
                       ENUM_SESSION_TYPE session,
                       double spread_pts,
                       double ai_confidence,
                       bool is_recent_profit_side,
                       MqlScoreBreakdown &out_breakdown)
     {
      ZeroMemory(out_breakdown);
      out_breakdown.direction = is_buy ? "BUY" : "SELL";

      // 1. Trend Alignment (Max: InpWeightTrend, e.g. 15.0)
      double ema9, ema20, ema50, ema200, ema_slope, price_dist;
      int trend_align = 0;
      engine.GetTrendFeatures(ema9, ema20, ema50, ema200, ema_slope, price_dist, trend_align);
      
      double trend_score = 0.0;
      if(is_buy)
        {
         if(ema9 > ema20) trend_score += (InpWeightTrend * 0.40);
         if(ema20 > ema50) trend_score += (InpWeightTrend * 0.35);
         if(ema50 > ema200) trend_score += (InpWeightTrend * 0.25);
        }
      else
        {
         if(ema9 < ema20) trend_score += (InpWeightTrend * 0.40);
         if(ema20 < ema50) trend_score += (InpWeightTrend * 0.35);
         if(ema50 < ema200) trend_score += (InpWeightTrend * 0.25);
        }
      out_breakdown.score_trend = MathMin(InpWeightTrend, trend_score);

      // 2. Market Structure / BOS / CHoCH (Max: InpWeightStructure, e.g. 15.0)
      ENUM_STRUCTURE_EVENT struct_evt = smc.GetLastStructureEvent();
      double struct_score = 0.0;
      if(is_buy)
        {
         if(struct_evt == STRUCT_BOS_BULL)   struct_score = InpWeightStructure * 1.0;
         else if(struct_evt == STRUCT_CHOCH_BULL) struct_score = InpWeightStructure * 0.85;
         else if(struct_evt == STRUCT_SWEEP_SSL)  struct_score = InpWeightStructure * 0.90;
         else if(trend_align > 0) struct_score = InpWeightStructure * 0.40;
        }
      else
        {
         if(struct_evt == STRUCT_BOS_BEAR)   struct_score = InpWeightStructure * 1.0;
         else if(struct_evt == STRUCT_CHOCH_BEAR) struct_score = InpWeightStructure * 0.85;
         else if(struct_evt == STRUCT_SWEEP_BSL)  struct_score = InpWeightStructure * 0.90;
         else if(trend_align < 0) struct_score = InpWeightStructure * 0.40;
        }
      out_breakdown.score_structure = MathMin(InpWeightStructure, struct_score);

      // 3. Liquidity Event / Sweeps & Dealing Range (Max: InpWeightLiquidity, e.g. 15.0)
      double liq_score = 0.0;
      if(is_buy)
        {
         if(struct_evt == STRUCT_SWEEP_SSL) liq_score += (InpWeightLiquidity * 0.65);
         if(smc.IsInDiscountZone())          liq_score += (InpWeightLiquidity * 0.35);
        }
      else
        {
         if(struct_evt == STRUCT_SWEEP_BSL) liq_score += (InpWeightLiquidity * 0.65);
         if(smc.IsInPremiumZone())           liq_score += (InpWeightLiquidity * 0.35);
        }
      out_breakdown.score_liquidity = MathMin(InpWeightLiquidity, liq_score);

      // 4. Momentum (RSI, MACD, ADX) (Max: InpWeightMomentum, e.g. 10.0)
      double rsi, rsi_slope, macd_m, macd_s, macd_h, adx, di_plus, di_minus, body_s;
      engine.GetMomentumFeatures(rsi, rsi_slope, macd_m, macd_s, macd_h, adx, di_plus, di_minus, body_s);
      double mom_score = 0.0;
      if(is_buy)
        {
         if(rsi >= 45.0 && rsi <= 78.0) mom_score += (InpWeightMomentum * 0.35);
         if(macd_h > 0.0)                mom_score += (InpWeightMomentum * 0.35);
         if(di_plus > di_minus && adx >= 20.0) mom_score += (InpWeightMomentum * 0.30);
        }
      else
        {
         if(rsi <= 55.0 && rsi >= 22.0) mom_score += (InpWeightMomentum * 0.35);
         if(macd_h < 0.0)                mom_score += (InpWeightMomentum * 0.35);
         if(di_minus > di_plus && adx >= 20.0) mom_score += (InpWeightMomentum * 0.30);
        }
      out_breakdown.score_momentum = MathMin(InpWeightMomentum, mom_score);

      // 5. Volatility Regime (Max: InpWeightVolatility, e.g. 10.0)
      double atr, atr_pct, exp_ratio;
      engine.GetVolatilityFeatures(atr, atr_pct, exp_ratio);
      double vol_score = 0.0;
      if(regime != REGIME_HIGH_VOLATILITY && regime != REGIME_LOW_VOLATILITY && regime != REGIME_NEWS_RISK)
        {
         if(exp_ratio >= 0.85 && exp_ratio <= 1.35) vol_score += (InpWeightVolatility * 0.60);
         if(atr_pct >= 25.0 && atr_pct <= 80.0)      vol_score += (InpWeightVolatility * 0.40);
        }
      else if(regime == REGIME_HIGH_VOLATILITY)
        {
         vol_score += (InpWeightVolatility * 0.30);
        }
      out_breakdown.score_volatility = MathMin(InpWeightVolatility, vol_score);

      // 6. FVG / Order Block Tap (Max: InpWeightFVG_OB, e.g. 10.0)
      double fvg_ob_score = 0.0;
      MqlFairValueGap nearest_fvg;
      MqlOrderBlock nearest_ob;
      if(smc.GetNearestUnmitigatedFVG(is_buy, nearest_fvg))
         fvg_ob_score += (InpWeightFVG_OB * 0.50);
      if(smc.GetNearestUnmitigatedOB(is_buy, nearest_ob))
         fvg_ob_score += (InpWeightFVG_OB * 0.50);
      out_breakdown.score_fvg_ob = MathMin(InpWeightFVG_OB, fvg_ob_score);

      // 7. Multi-Timeframe Alignment (Max: InpWeightMTF, e.g. 10.0)
      double mtf_align = mtf.GetMTFAlignmentScore(); // -10.0 to +10.0
      double mtf_score = 0.0;
      if(is_buy && mtf_align > 0)
         mtf_score = (mtf_align / 10.0) * InpWeightMTF;
      else if(!is_buy && mtf_align < 0)
         mtf_score = (MathAbs(mtf_align) / 10.0) * InpWeightMTF;
      out_breakdown.score_mtf = MathMin(InpWeightMTF, MathMax(0.0, mtf_score));

      // 8. Spread Quality (Max: InpWeightSpread, e.g. 5.0)
      double spread_ratio = spread_pts / (double)MathMax(1, InpMaxSpreadPoints);
      double spread_score = (1.0 - MathMin(1.0, spread_ratio)) * InpWeightSpread;
      out_breakdown.score_spread = MathMin(InpWeightSpread, MathMax(0.0, spread_score));

      // 9. Session Quality (Max: InpWeightSession, e.g. 5.0)
      double sess_score = 0.0;
      if(session == SESSION_OVERLAP)      sess_score = InpWeightSession * 1.0;
      else if(session == SESSION_LONDON)  sess_score = InpWeightSession * 0.85;
      else if(session == SESSION_NY)      sess_score = InpWeightSession * 0.85;
      else if(session == SESSION_ASIAN)   sess_score = InpWeightSession * 0.50;
      else if(session == SESSION_CUSTOM)  sess_score = InpWeightSession * 0.75;
      out_breakdown.score_session = MathMin(InpWeightSession, sess_score);

      // 10. AI / Vibe-Trading Confidence (Max: InpWeightAI, e.g. 5.0)
      double ai_score = 0.0;
      if(ai_confidence > 0.0)
        {
         ai_score = (ai_confidence / 100.0) * InpWeightAI;
        }
      out_breakdown.score_ai = MathMin(InpWeightAI, ai_score);

      // 11. Trend Continuation Booster
      double booster_score = 0.0;
      if(InpEnableTrendBooster)
        {
         bool ema_aligned = is_buy ? (ema9 > ema20 && ema20 > ema50) : (ema9 < ema20 && ema20 < ema50);
         bool healthy_mom = is_buy ? (rsi >= 48.0 && rsi <= 78.0) : (rsi <= 52.0 && rsi >= 22.0);

         if(ema_aligned && healthy_mom)
           {
            if(is_recent_profit_side)
              {
               booster_score = InpTrendBoosterScore; // Full +10.0 pts bonus for winning trend continuation
              }
            else if(is_buy ? (mtf_align >= 4.0) : (mtf_align <= -4.0))
              {
               booster_score = InpTrendBoosterScore * 0.70; // +7.0 pts for strong MTF aligned trend
              }
           }
        }
      out_breakdown.score_booster = booster_score;

      // Sum Total Score
      out_breakdown.total_score = MathMin(100.0,
                                  out_breakdown.score_trend +
                                  out_breakdown.score_structure +
                                  out_breakdown.score_liquidity +
                                  out_breakdown.score_momentum +
                                  out_breakdown.score_volatility +
                                  out_breakdown.score_fvg_ob +
                                  out_breakdown.score_mtf +
                                  out_breakdown.score_spread +
                                  out_breakdown.score_session +
                                  out_breakdown.score_ai +
                                  out_breakdown.score_booster);

      // Format Explainable String
      out_breakdown.explanation = StringFormat("%s (Score: %.1f/100) [Trend: +%.1f, Struct: +%.1f, Liq: +%.1f, Mom: +%.1f, Vol: +%.1f, FVG/OB: +%.1f, MTF: +%.1f, Spread: +%.1f, Sess: +%.1f, AI: +%.1f, Boost: +%.1f]",
                                               out_breakdown.direction,
                                               out_breakdown.total_score,
                                               out_breakdown.score_trend,
                                               out_breakdown.score_structure,
                                               out_breakdown.score_liquidity,
                                               out_breakdown.score_momentum,
                                               out_breakdown.score_volatility,
                                               out_breakdown.score_fvg_ob,
                                               out_breakdown.score_mtf,
                                               out_breakdown.score_spread,
                                               out_breakdown.score_session,
                                               out_breakdown.score_ai,
                                               out_breakdown.score_booster);
     }

   //+---------------------------------------------------------------+
   //| Convert Score to Signal State                                 |
   //+---------------------------------------------------------------+
   ENUM_SIGNAL_STATE GetSignalState(double score)
     {
      if(score >= 90.0) return SIGNAL_EXTREME;
      if(score >= InpScoreThresholdStrong) return SIGNAL_STRONG;
      if(score >= InpScoreThresholdValid)  return SIGNAL_VALID;
      if(score >= 60.0) return SIGNAL_WEAK;
      return SIGNAL_NO_TRADE;
     }
  };
