@echo off
setlocal
title Motocross Madness 2 - HOST
echo ==============================================
echo         Motocross Madness 2
echo       www.siljo-planet.net
echo ==============================================
echo.

cd /d "%~dp0"

set "PSFILE=%~dp0LAUNCH_HOST.ps1"
if not exist "%PSFILE%" (
  echo ERROR: Missing file: %PSFILE%
  echo.
  pause
  exit /b 1
)

REM IMPORTANT: use start "" so quoted paths don't become the window title.
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%PSFILE%"
exit /b 0
