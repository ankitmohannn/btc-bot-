//+------------------------------------------------------------------+
//|                                          SmartScalper_Regime.mqh |
//|                                  Copyright 2026, Institutional AI |
//|                     Deterministic Market Regime Engine            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

#include "SmartScalper_Types.mqh"
#include "SmartScalper_Config.mqh"
#include "SmartScalper_FeatureEngine.mqh"
#include "SmartScalper_SMC.mqh"

//+------------------------------------------------------------------+
//| Market Regime Classifier Engine Class                            |
//+------------------------------------------------------------------+
class CSmartRegimeEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

public:
   CSmartRegimeEngine() : m_symbol(""), m_timeframe(PERIOD_M5) {}

   void Init(string symbol, ENUM_TIMEFRAMES tf=PERIOD_M5)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      m_timeframe = tf;
     }

   //+---------------------------------------------------------------+
   //| Classify Active Market Regime                                 |
   //+---------------------------------------------------------------+
   ENUM_MARKET_REGIME ClassifyRegime(CSmartFeatureEngine &engine, CSmartSMC &smc, double current_spread_pts)
     {
      // 1. Check Spread & Noise / News Risk
      if(current_spread_pts > (double)InpMaxSpreadPoints)
        {
         return REGIME_NEWS_RISK;
        }

      // Extract Features
      double ema9, ema20, ema50, ema200, ema_slope, price_dist;
      int trend_align = 0;
      engine.GetTrendFeatures(ema9, ema20, ema50, ema200, ema_slope, price_dist, trend_align);

      double rsi, rsi_slope, macd_m, macd_s, macd_h, adx, di_plus, di_minus, body_strength;
      engine.GetMomentumFeatures(rsi, rsi_slope, macd_m, macd_s, macd_h, adx, di_plus, di_minus, body_strength);

      double atr, atr_pct, expansion_ratio;
      engine.GetVolatilityFeatures(atr, atr_pct, expansion_ratio);

      ENUM_STRUCTURE_EVENT struct_evt = smc.GetLastStructureEvent();

      // 2. Liquidity Event Check (Sweep in current or prior bar)
      if(struct_evt == STRUCT_SWEEP_BSL || struct_evt == STRUCT_SWEEP_SSL)
        {
         return REGIME_LIQUIDITY_EVENT;
        }

      // 3. High Volatility Check
      if(atr_pct >= 85.0 || expansion_ratio >= 1.5)
        {
         return REGIME_HIGH_VOLATILITY;
        }

      // 4. Low Volatility / Compression Check
      if(atr_pct <= 18.0 || expansion_ratio <= 0.65)
        {
         return REGIME_LOW_VOLATILITY;
        }

      // 5. Reversal Check (CHoCH + Extreme RSI)
      if((struct_evt == STRUCT_CHOCH_BULL && rsi <= 35.0) ||
         (struct_evt == STRUCT_CHOCH_BEAR && rsi >= 65.0))
        {
         return REGIME_REVERSAL;
        }

      // 6. Breakout / Breakdown Check
      if(struct_evt == STRUCT_BOS_BULL && body_strength >= 65.0 && expansion_ratio >= 1.15)
        {
         return REGIME_BREAKOUT;
        }
      if(struct_evt == STRUCT_BOS_BEAR && body_strength >= 65.0 && expansion_ratio >= 1.15)
        {
         return REGIME_BREAKDOWN;
        }

      // 7. Strong Trending Regimes (ADX > 22, aligned EMAs)
      if(adx >= 22.0)
        {
         if(trend_align > 0 && di_plus > di_minus && ema9 > ema20)
            return REGIME_TRENDING_UP;
         if(trend_align < 0 && di_minus > di_plus && ema9 < ema20)
            return REGIME_TRENDING_DOWN;
        }

      // 8. Range Regime (Low ADX, RSI neutral, mixed structure)
      if(adx < 20.0 && rsi >= 40.0 && rsi <= 60.0)
        {
         return REGIME_RANGE;
        }

      // Default fallback based on trend alignment
      if(trend_align > 0) return REGIME_TRENDING_UP;
      if(trend_align < 0) return REGIME_TRENDING_DOWN;

      return REGIME_RANGE;
     }

   //+---------------------------------------------------------------+
   //| Get Regime-Specific Risk Sizing Multiplier (0.0 to 1.0)       |
   //+---------------------------------------------------------------+
   double GetRegimeRiskMultiplier(ENUM_MARKET_REGIME regime)
     {
      switch(regime)
        {
         case REGIME_TRENDING_UP:       return 1.0;  // Full institutional risk
         case REGIME_TRENDING_DOWN:     return 1.0;
         case REGIME_BREAKOUT:          return 0.9;
         case REGIME_BREAKDOWN:         return 0.9;
         case REGIME_REVERSAL:          return 0.75; // Moderated risk for counter-flow
         case REGIME_LIQUIDITY_EVENT:   return 0.85;
         case REGIME_RANGE:             return 0.70;
         case REGIME_HIGH_VOLATILITY:   return 0.50; // Reduce size for wide volatility
         case REGIME_LOW_VOLATILITY:    return 0.40; // Low probability of continuation
         case REGIME_NEWS_RISK:         return 0.0;  // Block trades
         default:                       return 0.0;
        }
     }

   //+---------------------------------------------------------------+
   //| Check if Regime Permits Trade Direction                       |
   //+---------------------------------------------------------------+
   bool IsRegimeDirectionAllowed(ENUM_MARKET_REGIME regime, bool is_buy)
     {
      if(regime == REGIME_NO_TRADE || regime == REGIME_NEWS_RISK)
         return false;

      if(regime == REGIME_TRENDING_UP && !is_buy)
         return false; // Do not short strong uptrends

      if(regime == REGIME_TRENDING_DOWN && is_buy)
         return false; // Do not long strong downtrends

      if(regime == REGIME_BREAKOUT && !is_buy)
         return false;

      if(regime == REGIME_BREAKDOWN && is_buy)
         return false;

      return true;
     }
  };
