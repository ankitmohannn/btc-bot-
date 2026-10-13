@echo off
set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"
title SmartScalper V2 - Multi-Timeframe Analytics Dashboard
cd /d "%~dp0"
echo ======================================================================
echo   STARTING SMARTSCALPER V2 - ANALYTICS & MONTE CARLO DASHBOARD
echo ======================================================================
echo.

python dashboard/server.py

pause
