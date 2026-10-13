//+------------------------------------------------------------------+
//|                                           SmartScalper_HUD.mqh   |
//|                                  Copyright 2026, Institutional AI |
//|          Institutional On-Chart HUD & Real-Time Diagnostics Panel |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

#include "SmartScalper_Types.mqh"
#include "SmartScalper_Config.mqh"

//+------------------------------------------------------------------+
//| Chart HUD Panel Engine Class                                     |
//+------------------------------------------------------------------+
class CSmartHUD
  {
private:
   string m_prefix;

public:
   CSmartHUD() : m_prefix("SSV2_HUD_") {}

   ~CSmartHUD()
     {
      RemoveHUD();
     }

   //+---------------------------------------------------------------+
   //| Remove all HUD graphical objects                              |
   //+---------------------------------------------------------------+
   void RemoveHUD()
     {
      int total = ObjectsTotal(0, 0, -1);
      for(int i = total - 1; i >= 0; i--)
        {
         string name = ObjectName(0, i, 0, -1);
         if(StringFind(name, m_prefix) == 0)
           {
            ObjectDelete(0, name);
           }
        }
     }

   //+---------------------------------------------------------------+
   //| Create or Update a Text Label                                 |
   //+---------------------------------------------------------------+
   void SetLabel(string suffix, string text, color clr, int x, int y, int font_size=9, bool bold=false)
     {
      string name = m_prefix + suffix;
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
        }
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
     }

   //+---------------------------------------------------------------+
   //| Create HUD Background Panel                                   |
   //+---------------------------------------------------------------+
   void CreateBackgroundPanel(int x, int y, int width, int height)
     {
      string name = m_prefix + "BG";
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
         ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
         ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'18,22,28');
         ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, name, OBJPROP_COLOR, C'45,55,72');
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
        }
     }

   //+---------------------------------------------------------------+
   //| Update Full HUD Panel                                         |
   //+---------------------------------------------------------------+
   void Render(string symbol,
               ENUM_MARKET_REGIME regime,
               ENUM_SESSION_TYPE session,
               string signal_dir,
               double score,
               double ai_conf,
               bool ai_online,
               double spread_pts,
               double current_atr,
               double candidate_lot,
               double candidate_rr,
               int open_trades,
               int trades_today,
               int losses_today,
               string filter_status,
               double basket_pnl=0.0)
     {
      if(!InpShowHUD)
        {
         RemoveHUD();
         return;
        }

      CreateBackgroundPanel(15, 25, 420, 245);

      // Line 1: Header
      string header_title = InpEnableBasketDCA ? "⚡ SMART SCALPER V2 | SMART BASKET DCA" : "⚡ SMART SCALPER V2 | INSTITUTIONAL SMC";
      SetLabel("Title", header_title, clrGold, 25, 35, 10, true);

      // Line 2: Market & Spread
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      color spread_clr = (spread_pts <= InpMaxSpreadPoints) ? clrLimeGreen : clrOrangeRed;
      string mkt_str = StringFormat("Market: %s | Bid: %s | Ask: %s | Spread: %.1f pts",
                                    symbol, DoubleToString(bid, digits), DoubleToString(ask, digits), spread_pts);
      SetLabel("Market", mkt_str, clrWhite, 25, 55, 9);

      // Line 3: Regime & Session
      color reg_clr = (regime == REGIME_TRENDING_UP || regime == REGIME_BREAKOUT) ? clrLime :
                      ((regime == REGIME_TRENDING_DOWN || regime == REGIME_BREAKDOWN) ? clrOrangeRed : clrSkyBlue);
      string reg_str = StringFormat("Regime: %-16s | Session: %s", RegimeToString(regime), SessionToString(session));
      SetLabel("Regime", reg_str, reg_clr, 25, 75, 9, true);

      // Line 4: Signal & State
      color sig_clr = (signal_dir == "BUY") ? clrLime : ((signal_dir == "SELL") ? clrOrangeRed : clrYellow);
      string sig_str = StringFormat("Signal: %-6s (Score: %.1f/100) | State: %s",
                                    signal_dir, score, (score >= InpScoreThresholdValid ? "VALID" : "FILTERED"));
      SetLabel("Signal", sig_str, sig_clr, 25, 95, 9, true);

      // Line 5: Score Progress Bar
      string bar = "";
      int filled = (int)(score / 10.0);
      filled = MathMax(0, MathMin(10, filled));
      for(int k = 0; k < 10; k++) bar += (k < filled) ? "■" : "□";
      color bar_clr = (score >= InpScoreThresholdStrong) ? clrLime : ((score >= InpScoreThresholdValid) ? clrAqua : clrDarkGray);
      string score_bar_str = StringFormat("Score Bar: [%s] %.1f%%", bar, score);
      SetLabel("ScoreBar", score_bar_str, bar_clr, 25, 115, 9);

      // Line 6: AI Bridge / Vibe-Trading Status
      color ai_clr = ai_online ? clrLime : (InpAIRequiredForEntry ? clrOrangeRed : clrOrange);
      string ai_text = ai_online ? StringFormat("ONLINE (Conf: %.1f%%)", ai_conf) : (InpAIRequiredForEntry ? "OFFLINE (BLOCKED)" : "OFFLINE (FAILSAFE ACTIVE)");
      string ai_str = StringFormat("AI Bridge: %s", ai_text);
      SetLabel("AIStatus", ai_str, ai_clr, 25, 135, 9);

      // Line 7: Risk & Execution Sizing
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double pnl = equity - balance;
      color pnl_clr = (pnl >= 0.0) ? clrLime : clrOrangeRed;
      string risk_str = StringFormat("Risk: %.1f%% | Lot: %.2f | Min RR: 1:%.2f | P/L: $%+.2f",
                                     InpRiskPercent, candidate_lot, candidate_rr, pnl);
      SetLabel("Risk", risk_str, clrWhite, 25, 155, 9);

      // Line 8: Active Positions & Session Stats
      string pos_str;
      if(InpEnableBasketDCA)
        {
         pos_str = StringFormat("Basket DCA: %d/%d | Basket PnL: $%+.2f (Target: +$%.2f)",
                                open_trades, InpMaxOpenTrades, basket_pnl, InpBasketTargetUSD);
        }
      else
        {
         pos_str = StringFormat("Active Basket: %d/%d (Cap: %.2f Lots) | PnL: $%+.2f",
                                open_trades, InpMaxOpenTrades, InpMaxTotalBasketLots, basket_pnl);
        }
      SetLabel("Positions", pos_str, (open_trades > 0 ? (basket_pnl >= 0 ? clrLime : clrOrange) : clrSilver), 25, 175, 9);

      // Line 9: Status / Filter Gate Message
      color gate_clr = (filter_status == "APPROVED") ? clrLime : clrYellow;
      string gate_str = StringFormat("Gate Status: %s", filter_status);
      SetLabel("Gate", gate_str, gate_clr, 25, 195, 9, true);

      // Line 10: ATR & Volatility Info
      string atr_str = StringFormat("ATR(14): %.5f | ATR SL Mult: %.1fx", current_atr, InpATRMultiplierSL);
      SetLabel("ATR", atr_str, clrLightSlateGray, 25, 215, 8);

      ChartRedraw(0);
     }
  };
