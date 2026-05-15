@echo off
REM Alfapos — Windows release build (CMD)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_windows.ps1"
if errorlevel 1 exit /b 1
pause
