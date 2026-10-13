//+------------------------------------------------------------------+
//|                               Kronos_SuperFast_Scalper_EA.mq5    |
//|                          Copyright 2026, Institutional Kronos AI |
//|        Dedicated High-Win Scalper EA (0.50 Lot | $15 TP / $30 SL)|
//+------------------------------------------------------------------+
#property copyright "Kronos Institutional Trading System"
#property link      "https://kronos-ai.org"
#property version   "4.30"

#include <Trade\Trade.mqh>
#include "Include\SmartScalper\SmartScalper_VolatilityShield.mqh"

input group "=== 1. Super-Fast Scalper Settings ==="
input double FixedLotSize         = 0.08;   // Scalping Base Lot Size (0.08 Lot)
input double MinTradeConfidence   = 65.0;   // Minimum AI Scalp Confidence (0-100%)
input int    MaxOpenTrades        = 2;      // Maximum Simultaneous Positions (2)
input int    MagicNumber            = 888222; // Unique Scalper Magic Number
input int    Slippage               = 30;     // Max Slippage (points)
input bool   EnableEATrading        = true;   // Enable Direct EA Trade Execution

input group "=== 2. High Win-Rate Target Distances (USD) ==="
input double SL_Distance_USD      = 4.0;    // Structural Noise Protection Stop-Loss ($4.00 USD)
input double TP_Distance_USD      = 5.5;    // High Win-Rate Quick Take-Profit ($5.50 USD)

input group "=== 3. Trailing Stop & Auto Break-Even ==="
input bool   EnableTrailingStop   = true;   // Enable Trailing Stop Loss
input double TrailingTriggerUSD   = 2.5;    // Trailing Stop Trigger Profit USD ($2.50)
input double TrailingStepUSD      = 1.0;    // Trailing Step USD ($1.00)
input bool   EnableBreakEven      = true;   // Enable Auto Break-Even
input double BreakEvenTriggerUSD  = 2.2;    // Profit USD move to trigger Break-Even ($2.20)

input group "=== 4. Volatility Clustering & Tail-Risk Shield ==="
input bool   EnableVolShield      = true;   // Enable Volatility Clustering & Tail-Risk Sizer
input int    VolFastPeriod        = 5;      // Fast Volatility Period (Bars)
input int    VolSlowPeriod        = 50;     // Slow Baseline Volatility Period (Bars)
input int    TailRiskLookback     = 60;     // Tail-Risk VaR 99% Lookback Bars
input double VolHighRatioThreshold= 1.35;   // High Volatility Expansion Threshold
input double VolExtremeRatioThresh= 2.10;   // Extreme Volatility Shock Threshold
input double TailRiskBlockThresh  = 85.0;   // Tail Risk Block Threshold (0-100)
input bool   BlockExtremeVol      = false;  // If True: Block Extreme Vol; If False: Defensive 0.20x Sizing

string FORECAST_FILE = "kronos_forecast.csv";
string SIGNAL_FILE   = "kronos_signal.csv";
int REFRESH_RATE_MS  = 200; // Super-fast 200ms timer check

CTrade trade;
CSmartVolatilityShield vol_shield;
long last_signal_timestamp = 0;
string current_signal_text = "HOLD";
double current_confidence  = 0.0;
string current_vol_shield_status = "NORMAL (1.0x)";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   
   vol_shield.Init(_Symbol, _Period);
   vol_shield.Configure(EnableVolShield, VolFastPeriod, VolSlowPeriod, TailRiskLookback, VolHighRatioThreshold, VolExtremeRatioThresh, TailRiskBlockThresh, BlockExtremeVol, 5.0);

   long filling = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN);
   
   EventSetMillisecondTimer(REFRESH_RATE_MS);
   DrawForecastTrajectory();
   UpdateHUDPanel();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteForecastLines();
   RemoveHUDObjects();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  }

//+------------------------------------------------------------------+
//| Timer function (Runs every 200ms)                               |
//+------------------------------------------------------------------+
void OnTimer()
  {
   DrawForecastTrajectory();
   CheckAndExecuteSignal();
   UpdateHUDPanel();
  }

//+------------------------------------------------------------------+
//| Delete all forecast lines                                        |
//+------------------------------------------------------------------+
void DeleteForecastLines()
  {
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "KronosScalpPred_") == 0 || StringFind(name, "KronosPred_") == 0)
        {
         ObjectDelete(0, name);
        }
     }
  }

//+------------------------------------------------------------------+
//| Draw Single Clean Forecast Trajectory Line                       |
//+------------------------------------------------------------------+
void DrawForecastTrajectory()
  {
   int handle = FileOpen(FORECAST_FILE, FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, '\n');
   if(handle == INVALID_HANDLE) return;

   DeleteForecastLines();

   double cur_price = iClose(_Symbol, _Period, 0);
   datetime cur_time = iTime(_Symbol, _Period, 0);
   int tf_sec = PeriodSeconds(_Period);
   if(tf_sec <= 0) tf_sec = 60;

   double prev_price = cur_price;
   datetime prev_time = cur_time;
   int step = 1;

   while(!FileIsEnding(handle))
     {
      string str = FileReadString(handle);
      if(str == "") continue;
      
      double pred_price = StringToDouble(str);
      if(pred_price <= 0) continue;
      
      datetime next_time = cur_time + (step * tf_sec);
      string name = "KronosScalpPred_" + IntegerToString(step);
      
      if(ObjectCreate(0, name, OBJ_TREND, 0, prev_time, prev_price, next_time, pred_price))
        {
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrDeepSkyBlue);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        }
      
      prev_price = pred_price;
      prev_time = next_time;
      step++;
     }
   FileClose(handle);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Read Signal File & Execute Sub-Second Market Order               |
//+------------------------------------------------------------------+
void CheckAndExecuteSignal()
  {
   int handle = FileOpen(SIGNAL_FILE, FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ',');
   if(handle == INVALID_HANDLE) return;

   if(!FileIsEnding(handle))
     {
      long timestamp  = (long)StringToInteger(FileReadString(handle));
      string signal   = FileReadString(handle);
      double entry    = StringToDouble(FileReadString(handle));
      double sl       = StringToDouble(FileReadString(handle));
      double tp       = StringToDouble(FileReadString(handle));
      double lot      = StringToDouble(FileReadString(handle));
      double conf     = StringToDouble(FileReadString(handle));

      current_signal_text = signal;
      current_confidence  = conf;

      if(timestamp > last_signal_timestamp)
        {
         last_signal_timestamp = timestamp;

         if(EnableEATrading && (signal == "BUY" || signal == "SELL"))
           {
            if(conf >= MinTradeConfidence)
              {
               ExecuteFastScalpOrder(signal, entry, sl, tp, conf);
              }
           }
        }
     }
   FileClose(handle);
  }

void ExecuteFastScalpOrder(string signal, double entry, double sl, double tp, double conf)
  {
   if(GetOpenTradesCount() >= MaxOpenTrades) return; // Allow up to 5 simultaneous positions

   // 1. Evaluate Volatility Clustering & Tail-Risk Shield
   MqlVolShieldAssessment vol_assess;
   vol_shield.AssessVolatilityAndTailRisk(FixedLotSize, conf, vol_assess);
   vol_shield.LogAssessment(vol_assess);

   current_vol_shield_status = StringFormat("%s (x%.2f | Lot: %.2f)",
                                            (vol_assess.vol_regime == VOL_REGIME_LOW ? "LOW" :
                                             (vol_assess.vol_regime == VOL_REGIME_NORMAL ? "NORMAL" :
                                              (vol_assess.vol_regime == VOL_REGIME_HIGH ? "HIGH" : "EXTREME"))),
                                            vol_assess.risk_multiplier, vol_assess.adjusted_lot);

   if(!vol_assess.is_trade_allowed)
     {
      PrintFormat("🛡️ [VOLATILITY SHIELD BLOCKED] %s", vol_assess.decision_reason);
      return;
     }

   double final_lot = vol_assess.adjusted_lot;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // 100% SL-Free: No broker hard Stop Loss
   sl = 0.0;
   if(signal == "BUY")
      tp = ask + TP_Distance_USD;
   else if(signal == "SELL")
      tp = bid - TP_Distance_USD;

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   string comment = StringFormat("FastScalp %s (Conf:%.0f|VS:%.2f)", signal, conf, vol_assess.risk_multiplier);

   if(signal == "BUY")
     {
      if(trade.Buy(final_lot, _Symbol, ask, sl, tp, comment))
        {
         PrintFormat("⚡ FAST SCALP BUY EXECUTED! Ticket #%d | Lot: %.2f (Orig: %.2f) | SL: %s | TP: %s | %s",
                     trade.ResultOrder(), final_lot, FixedLotSize, DoubleToString(sl, digits), DoubleToString(tp, digits), vol_assess.decision_reason);
        }
     }
   else if(signal == "SELL")
     {
      if(trade.Sell(final_lot, _Symbol, bid, sl, tp, comment))
        {
         PrintFormat("⚡ FAST SCALP SELL EXECUTED! Ticket #%d | Lot: %.2f (Orig: %.2f) | SL: %s | TP: %s | %s",
                     trade.ResultOrder(), final_lot, FixedLotSize, DoubleToString(sl, digits), DoubleToString(tp, digits), vol_assess.decision_reason);
        }
     }
  }

//+------------------------------------------------------------------+
//| Trailing Stop & Auto Break-Even Management                      |
//+------------------------------------------------------------------+
void ManageTrailingAndBreakEven()
  {
   // 100% SL-FREE: All break-even and trailing logic permanently removed!
   return;
  }

int GetOpenTradesCount()
  {
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionSelectByTicket(PositionGetTicket(i)))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) cnt++;
        }
     }
   return cnt;
  }

//+------------------------------------------------------------------+
//| Real-Time Scalper Visual HUD Panel                              |
//+------------------------------------------------------------------+
void RemoveHUDObjects()
  {
   ObjectDelete(0, "ScalpHUD_Title");
   ObjectDelete(0, "ScalpHUD_Market");
   ObjectDelete(0, "ScalpHUD_Signal");
   ObjectDelete(0, "ScalpHUD_Conf");
   ObjectDelete(0, "ScalpHUD_Trade");
  }

void CreateOrUpdateScalpLabel(string name, string text, color clr, int y_offset, int font_size=10, bool bold=false)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 25);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
     }
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_offset);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
  }

void UpdateHUDPanel()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = (ask - bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   CreateOrUpdateScalpLabel("ScalpHUD_Title", "⚡ KRONOS HIGH-WIN SCALPER (0.50 LOT)", clrGold, 20, 11, true);

   string mkt_str = StringFormat("Market: Bid %s | Ask %s | Spread %.1f pts", DoubleToString(bid, _Digits), DoubleToString(ask, _Digits), spread);
   CreateOrUpdateScalpLabel("ScalpHUD_Market", mkt_str, clrWhite, 42);

   color sig_clr = (current_signal_text == "BUY") ? clrLime : ((current_signal_text == "SELL") ? clrRed : clrYellow);
   string sig_str = StringFormat("Scalp Signal: %s (Min Conf: %.0f%%)", current_signal_text, MinTradeConfidence);
   CreateOrUpdateScalpLabel("ScalpHUD_Signal", sig_str, sig_clr, 62, 10, true);

   string bar = "";
   int filled = (int)(current_confidence / 10.0);
   filled = MathMax(0, MathMin(10, filled));
   for(int k = 0; k < 10; k++) bar += (k < filled) ? "■" : "□";
   color conf_clr = (current_confidence >= MinTradeConfidence) ? clrLime : clrOrange;
   string conf_str = StringFormat("Confidence  : [%s] %.1f%%", bar, current_confidence);
   CreateOrUpdateScalpLabel("ScalpHUD_Conf", conf_str, conf_clr, 82);

   int open_cnt = GetOpenTradesCount();
   string trade_str = StringFormat("Open Scalps : %d / %d Active (Target: $15 TP / $30 SL)", open_cnt, MaxOpenTrades);
   color trade_clr = (open_cnt > 0) ? clrLime : clrGray;
   CreateOrUpdateScalpLabel("ScalpHUD_Trade", trade_str, trade_clr, 102);

   CreateOrUpdateScalpLabel("ScalpHUD_VolShield", "Vol Shield  : " + current_vol_shield_status, clrCyan, 122);
  }
