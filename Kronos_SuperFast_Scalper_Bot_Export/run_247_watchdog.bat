@echo off
set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"
title SmartScalper V2 - 24/7 Self-Healing Watchdog Supervisor (BTCUSD)
cd /d "%~dp0"

echo ======================================================================
echo          SMARTSCALPER V2 - 24/7 SELF-HEALING SUPERVISOR
echo          Monitors AI Bridge & BTCUSD Scalper with Auto-Revival
echo ======================================================================
echo.

python -u bridge_247_watchdog.py BTCUSD M5

pause

