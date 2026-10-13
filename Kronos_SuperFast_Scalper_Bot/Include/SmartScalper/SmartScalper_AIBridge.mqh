//+------------------------------------------------------------------+
//|                                       SmartScalper_AIBridge.mqh  |
//|                                  Copyright 2026, Institutional AI |
//|          Resilient Structured Python / Vibe-Trading AI Bridge     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

#include "SmartScalper_Types.mqh"
#include "SmartScalper_Config.mqh"

//+------------------------------------------------------------------+
//| AI Bridge Communication Class                                    |
//+------------------------------------------------------------------+
class CSmartAIBridge
  {
private:
   string            m_symbol;
   string            m_features_file;
   string            m_signals_file;
   
   MqlAISignalPacket m_latest_signal;
   datetime          m_last_packet_received_time;
   bool              m_is_online;

public:
   CSmartAIBridge() : m_symbol(""),
                      m_features_file("smart_scalper_features.json"),
                      m_signals_file("smart_scalper_signal.json"),
                      m_last_packet_received_time(0),
                      m_is_online(false)
     {
      ZeroMemory(m_latest_signal);
     }

   void Init(string symbol)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
     }

   //+---------------------------------------------------------------+
   //| Export Structured Feature Packet to Bridge File               |
   //+---------------------------------------------------------------+
   bool ExportFeaturePacket(const MqlFeaturePacket &packet)
     {
      int handle = FileOpen(m_features_file, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
      if(handle == INVALID_HANDLE)
        {
         handle = FileOpen(m_features_file, FILE_WRITE|FILE_TXT|FILE_ANSI);
        }
      if(handle == INVALID_HANDLE) return false;

      // Construct JSON formatted string
      string json = "{\n";
      json += StringFormat("  \"symbol\": \"%s\",\n", packet.symbol);
      json += StringFormat("  \"timestamp\": %d,\n", (long)packet.timestamp);
      json += StringFormat("  \"bid\": %.5f,\n", packet.bid);
      json += StringFormat("  \"ask\": %.5f,\n", packet.ask);
      json += StringFormat("  \"spread\": %.2f,\n", packet.spread_points);
      json += StringFormat("  \"timeframe_sec\": %d,\n", packet.timeframe_seconds);
      json += StringFormat("  \"open\": %.5f,\n", packet.open);
      json += StringFormat("  \"high\": %.5f,\n", packet.high);
      json += StringFormat("  \"low\": %.5f,\n", packet.low);
      json += StringFormat("  \"close\": %.5f,\n", packet.close);
      json += StringFormat("  \"volume\": %d,\n", packet.tick_volume);
      json += StringFormat("  \"atr\": %.5f,\n", packet.atr_m5);
      json += StringFormat("  \"rsi\": %.2f,\n", packet.rsi_m5);
      json += StringFormat("  \"adx\": %.2f,\n", packet.adx_m5);
      json += StringFormat("  \"ema9\": %.5f,\n", packet.ema9_m5);
      json += StringFormat("  \"ema20\": %.5f,\n", packet.ema20_m5);
      json += StringFormat("  \"ema50\": %.5f,\n", packet.ema50_m5);
      json += StringFormat("  \"ema200\": %.5f,\n", packet.ema200_m5);
      json += StringFormat("  \"regime_id\": %d,\n", packet.regime_id);
      json += StringFormat("  \"structure_id\": %d,\n", packet.structure_id);
      json += StringFormat("  \"session_id\": %d,\n", packet.session_id);
      json += StringFormat("  \"win_rate\": %.1f,\n", packet.recent_win_rate);
      json += StringFormat("  \"losses\": %d\n", packet.consecutive_losses);
      json += "}\n";

      FileWriteString(handle, json);
      FileClose(handle);
      return true;
     }

   //+---------------------------------------------------------------+
   //| Ingest Structured Signal Packet from AI Bridge                |
   //+---------------------------------------------------------------+
   bool IngestSignalPacket(MqlAISignalPacket &out_signal)
     {
      if(!InpEnableAIBridge)
        {
         m_is_online = false;
         m_latest_signal.confidence = 0.0;
         m_latest_signal.is_valid = false;
         out_signal = m_latest_signal;
         return false;
        }

      datetime now = TimeCurrent();
      int handle = INVALID_HANDLE;
      string filenames[4];
      filenames[0] = "smart_scalper_signal.json";
      filenames[1] = "smart_scalper_signal_" + m_symbol + ".json";
      filenames[2] = "kronos_signal_" + m_symbol + ".csv";
      filenames[3] = "kronos_signal.csv";

      string full_content = "";
      bool is_json = true;

      // Try local terminal files first, then common files
      for(int f = 0; f < 4; f++)
        {
         handle = FileOpen(filenames[f], FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
         if(handle == INVALID_HANDLE)
           {
            handle = FileOpen(filenames[f], FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
           }
         if(handle != INVALID_HANDLE)
           {
            full_content = "";
            while(!FileIsEnding(handle))
              {
               full_content += FileReadString(handle) + "\n";
              }
            FileClose(handle);
            if(StringLen(full_content) >= 10)
              {
               is_json = (StringFind(filenames[f], ".json") >= 0);
               break;
              }
           }
        }

      if(StringLen(full_content) < 5)
        {
         if(m_last_packet_received_time > 0 && (now - m_last_packet_received_time) <= m_latest_signal.valid_for_seconds)
           {
            out_signal = m_latest_signal;
            return m_is_online;
           }
         m_is_online = false;
         m_latest_signal.confidence = 0.0;
         m_latest_signal.is_valid = false;
         out_signal = m_latest_signal;
         return false;
        }

      if(is_json)
        {
         // Parse JSON Key-Values safely
         m_latest_signal.symbol        = ExtractJsonString(full_content, "symbol");
         m_latest_signal.direction     = ExtractJsonString(full_content, "direction");
         m_latest_signal.confidence    = ExtractJsonDouble(full_content, "confidence");
         m_latest_signal.regime        = (ENUM_MARKET_REGIME)((int)ExtractJsonDouble(full_content, "regime_id"));
         m_latest_signal.expected_move = ExtractJsonDouble(full_content, "expected_move");
         m_latest_signal.risk_score    = ExtractJsonDouble(full_content, "risk_score");
         m_latest_signal.valid_for_seconds = (int)ExtractJsonDouble(full_content, "valid_for_seconds");
         if(m_latest_signal.valid_for_seconds <= 0) m_latest_signal.valid_for_seconds = 120;

         long ts = (long)ExtractJsonDouble(full_content, "timestamp");
         m_latest_signal.generated_time = (datetime)ts;
         m_latest_signal.reason_codes  = ExtractJsonString(full_content, "reason_codes");
        }
      else
        {
         // Parse CSV format: ts,signal,cur_close,sl,tp,lot,confidence
         string parts[];
         int count = StringSplit(full_content, ',', parts);
         if(count >= 7)
           {
            m_latest_signal.symbol = m_symbol;
            m_latest_signal.direction = parts[1];
            m_latest_signal.confidence = StringToDouble(parts[6]);
            m_latest_signal.valid_for_seconds = 120;
            m_latest_signal.generated_time = now;
            m_latest_signal.reason_codes = "KRONOS_AI_CSV_STREAM";
           }
        }

      // Validate signal freshness against TTL
      if(m_latest_signal.generated_time > 0 && MathAbs((long)now - (long)m_latest_signal.generated_time) > m_latest_signal.valid_for_seconds)
        {
         m_is_online = false;
         m_latest_signal.confidence = 0.0;
         m_latest_signal.is_valid = false;
         out_signal = m_latest_signal;
         return false;
        }

      // Signal is online and fresh
      m_latest_signal.is_valid = true;
      m_is_online = true;
      m_last_packet_received_time = now;

      out_signal = m_latest_signal;
      return m_is_online;
     }

   bool   IsOnline()                { return m_is_online; }
   double GetLatestAIConfidence()   { return m_latest_signal.confidence; }
   string GetLatestReasonCodes()    { return m_latest_signal.reason_codes; }

private:
   //+---------------------------------------------------------------+
   //| Simple Robust JSON String Extractor                           |
   //+---------------------------------------------------------------+
   string ExtractJsonString(string json, string key)
     {
      string search = "\"" + key + "\":";
      int pos = StringFind(json, search);
      if(pos < 0) return "";

      int start_q = StringFind(json, "\"", pos + StringLen(search));
      if(start_q < 0) return "";
      int end_q = StringFind(json, "\"", start_q + 1);
      if(end_q < 0) return "";

      return StringSubstr(json, start_q + 1, end_q - start_q - 1);
     }

   //+---------------------------------------------------------------+
   //| Simple Robust JSON Double Extractor                           |
   //+---------------------------------------------------------------+
   double ExtractJsonDouble(string json, string key)
     {
      string search = "\"" + key + "\":";
      int pos = StringFind(json, search);
      if(pos < 0) return 0.0;

      int start = pos + StringLen(search);
      while(start < StringLen(json) && (StringGetCharacter(json, start) == ' ' || StringGetCharacter(json, start) == '\t'))
         start++;

      int end = start;
      while(end < StringLen(json))
        {
         ushort ch = StringGetCharacter(json, end);
         if((ch >= '0' && ch <= '9') || ch == '.' || ch == '-')
            end++;
         else
            break;
        }

      string num_str = StringSubstr(json, start, end - start);
      return StringToDouble(num_str);
     }
  };
