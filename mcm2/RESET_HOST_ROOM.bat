@echo off
setlocal
title Motocross Madness 2 - Reset saved host room
echo ==============================================
echo         Motocross Madness 2
echo       www.siljo-planet.net
echo ==============================================
echo.

if exist "%~dp0host_room.txt" (
  del /f /q "%~dp0host_room.txt"
  echo OK: Saved host room removed (host_room.txt).
) else (
  echo No saved host room found (host_room.txt not present).
)

echo.
pause
exit /b 0
