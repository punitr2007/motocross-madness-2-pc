@echo off
setlocal
title Motocross Madness 2 - Stop Hosting
echo ==============================================
echo         Motocross Madness 2
echo       www.siljo-planet.net
echo ==============================================
echo.

set "PSFILE=%~dp0STOP_HOSTING.ps1"
if not exist "%PSFILE%" (
  echo ERROR: Missing file: %PSFILE%
  echo.
  pause
  exit /b 1
)

powershell -NoProfile -STA -ExecutionPolicy Bypass -File "%PSFILE%"
echo.
echo (STOP finished) Press any key to close...
pause >nul
exit /b 0
