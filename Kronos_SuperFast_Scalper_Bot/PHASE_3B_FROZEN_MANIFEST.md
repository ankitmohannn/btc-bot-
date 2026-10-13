# PHASE 3B — FROZEN SYSTEM MANIFEST

**Date of Freeze**: 2026-08-22  
**Status**: **FROZEN & LOCKED FOR ADVERSARIAL ROBUSTNESS TESTING**  
**Integrity Guarantee**: All strategy logic, parameters, indicators, and baseline codes are frozen. No strategy modifications or parameter optimizations are permitted during Phase 3B testing.

---

## 1. Frozen Source File Manifest & SHA-256 Checksums

| Component / File Path | File Type | SHA-256 Checksum |
|---|---|---|
| `SmartScalper_V2.mq5` | Master EA | `9A5C4734B3F36DE23E02CBA7BC42B182AEA18F57F305E55F35A814ABBFA5976C` |
| `Kronos_SuperFast_Scalper_EA.mq5` | Baseline EA | `AD9A0F15429902FDF90F21BB1F0323230448064303BE1379891003BF47EA8A69` |
| `Include/SmartScalper/SmartScalper_Types.mqh` | Types & Structs | `854F2347B99E1EA953AFB45FA99FC8F6030AB3EE04EA6A420CE438238CF8CCAD` |
| `Include/SmartScalper/SmartScalper_Config.mqh` | Inputs & Config | `7A1CFDFE292D338458E21CF2E7D64CF6AAA068DA0FEE49CAA40EDF680FD30F44` |
| `Include/SmartScalper/SmartScalper_FeatureEngine.mqh` | Feature Engine | `3E0DD4268B6441FB17D15E84B0F63C63164E53C9998D93AAA4ACBD28A0C00C24` |
| `Include/SmartScalper/SmartScalper_SMC.mqh` | SMC & Structure | `CBC0E8E02FF75AECF9B892B38CF3A28E8C0C14D303DB73E4D6313E083B6A0481` |
| `Include/SmartScalper/SmartScalper_MTF.mqh` | Multi-Timeframe | `82618C845841722967F2543B671A1DB59D58BE284485E1C81DE23174C8A61836` |
| `Include/SmartScalper/SmartScalper_Regime.mqh` | Market Regime | `455659FE355E977ABC822EF64DD0C36C1B01A474392F47CD7EB6F3713F2B71FD` |
| `Include/SmartScalper/SmartScalper_Scoring.mqh` | Scoring Engine | `96A0E314E6CFEE9BFC53FA4A2AFD0DDE6BC968748E18DE342A5184EA2C01D356` |
| `Include/SmartScalper/SmartScalper_RiskEngine.mqh` | Risk & Lot Sizing | `61C03DF0EED9A344F3F8A033D50FE7F27C6354223D76D2580693DA61AB63F015` |
| `Include/SmartScalper/SmartScalper_TradeManager.mqh` | Trade Manager | `4087B8D32CFC7C73229843EB9C93840BB0A8146537221F7CDD16818173160482` |
| `Include/SmartScalper/SmartScalper_Filters.mqh` | Filters & Safety | `4210E14623F7B812C2D93E1FE23959542F5BC93E244D79D51B0011970659A697` |
| `Include/SmartScalper/SmartScalper_AIBridge.mqh` | AI Bridge IPC | `96FCC954168C33382E456EC51925B0C1BAEB6E1689CB05FB6F92FA9ADB34832A` |
| `Include/SmartScalper/SmartScalper_Journal.mqh` | Trade Journal | `2A7662AD95B20670526366D357E56050194CB5B7677CDFBAE4705078501CC39B` |
| `Include/SmartScalper/SmartScalper_HUD.mqh` | Chart Dashboard | `AED3B1E023A9584C7459D15F9B35A35DE26B7A66B143F02A3CF9B5922960CFD0` |

---

## 2. Python Bridge Files

| File Path | SHA-256 Checksum |
|---|---|
| `ai/bridge/feature_packet.py` | `0B1FFC7094917B090F166DE76C12E7DF0175BD5A901EF3975C4C21FE91AF2743` |
| `ai/bridge/signal_packet.py` | `6A0DAE16A27BEB03607BA1431713DC2546D5EC3EC39A440D9B0556276FF3E31A` |
| `ai/bridge/vibe_trading_adapter.py` | `378F72AC393A248A80E6593DF0F3FB8728CAAC8F0EFDCB9C694939C0503D00D0` |
| `ai/bridge/ai_bridge_server.py` | `29548E3FB24B7003463806C131804FD181A0563462E129B7F1DF8286A2B3766E` |
| `ai/bridge/research_evaluator.py` | `D1865961556C47A704533038D121B7208E6C84318F1286C33D29528EB9FB2BC4` |

---

## 3. Frozen State Confirmation

1. `SmartScalper_V2.mq5` exists and compiles to `SmartScalper_V2.ex5` (0 errors, 0 warnings).
2. `Kronos_SuperFast_Scalper_EA.mq5` exists and is 100% identical to initial baseline.
3. `PHASE_3A_ABLATION_REPORT.md` exists and is archived.
4. All Phase 3B stress tests will execute against this frozen code snapshot using an external test runner.
