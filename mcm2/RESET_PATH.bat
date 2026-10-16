@echo off
setlocal
title Motocross Madness 2 - Reset saved path
echo ==============================================
echo         Motocross Madness 2
echo       www.siljo-planet.net
echo ==============================================
echo.

if exist "%~dp0game_path.txt" (
  del /f /q "%~dp0game_path.txt"
  echo OK: Saved path removed (game_path.txt).
) else (
  echo No saved path found (game_path.txt not present).
)

echo.
pause
exit /b 0
