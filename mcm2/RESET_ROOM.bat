@echo off
setlocal
title Motocross Madness 2 - Reset saved room
echo ==============================================
echo         Motocross Madness 2
echo       www.siljo-planet.net
echo ==============================================
echo.

if exist "%~dp0room_code.txt" (
  del /f /q "%~dp0room_code.txt"
  echo OK: Saved room removed (room_code.txt).
) else (
  echo No saved room found (room_code.txt not present).
)

echo.
pause
exit /b 0
