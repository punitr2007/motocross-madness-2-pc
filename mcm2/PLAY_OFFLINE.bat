@echo off
setlocal
title Motocross Madness 2 - Direct Play
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0PLAY_OFFLINE.ps1"
if %ERRORLEVEL% neq 0 (
  echo.
  echo Launcher encountered an error.
  pause
)
