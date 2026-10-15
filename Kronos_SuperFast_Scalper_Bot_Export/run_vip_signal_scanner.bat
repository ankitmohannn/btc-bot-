@echo off
title Kronos VIP Institutional Signal Scanner
echo ==================================================================
echo   KRONOS VIP INSTITUTIONAL SIGNAL SCANNER (24/7 Background Service)
echo ==================================================================
echo.
cd /d "%~dp0"
python kronos_vip_signal_scanner.py --symbols BTCUSD --interval 20
pause

