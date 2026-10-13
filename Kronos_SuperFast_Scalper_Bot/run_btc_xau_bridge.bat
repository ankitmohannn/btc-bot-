@echo off
set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"
title Kronos & SmartScalper Master 24/7 Bridge Launcher
cd /d "%~dp0"

echo ======================================================================
echo    KRONOS & SMARTSCALPER MASTER 24/7 DUAL ASSET BRIDGE LAUNCHER
echo ======================================================================
echo.
echo 1. Starting AI Bridge Server (turns MT5 EA Status to ONLINE)...
echo 2. Starting BTCUSD Scalper Engine (24/7 Auto-Restart)...
echo 3. Starting XAUUSD Scalper Engine (24/7 Auto-Restart)...
echo.

:: 1. Launch AI Bridge Server for MT5 EA HUD & Signals
start "SmartScalper AI Bridge Server (MT5 ONLINE)" cmd /k "cd /d ""%~dp0"" && :loop && python -u ai\bridge\ai_bridge_server.py && echo AI Bridge exited. Restarting in 3s... && timeout /t 3 /nobreak >nul && goto loop"

:: 2. Launch BTCUSD Scalper Engine
start "Kronos Scalper - BTCUSD (24/7)" cmd /k "cd /d ""%~dp0"" && :loop && python super_fast_scalper.py --symbol BTCUSD --lot 0.5 && echo Scalper BTC exited. Restarting in 3s... && timeout /t 3 /nobreak >nul && goto loop"

:: 3. Launch XAUUSD Scalper Engine
start "Kronos Scalper - XAUUSD (24/7)" cmd /k "cd /d ""%~dp0"" && :loop && python super_fast_scalper.py --symbol XAUUSD --lot 0.5 && echo Scalper XAU exited. Restarting in 3s... && timeout /t 3 /nobreak >nul && goto loop"

echo ======================================================================
echo [OK] ALL 3 BRIDGES & SCALPERS ARE RUNNING AND MONITORED 24/7!
echo ======================================================================
echo You can minimize this window.
pause
