@echo off
REM Double-click launcher for the auto-mirror watcher.
REM Runs the PowerShell script, bypassing the execution policy
REM just for this one process (does not change system settings).
setlocal
title scrcpy auto-mirror watcher
cd /d "%~dp0"

set "SCRIPT=%~dp0auto-mirror-watch.ps1"
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%SCRIPT%" (
    echo Could not find: "%SCRIPT%"
    pause
    exit /b 1
)

if not exist "%POWERSHELL%" set "POWERSHELL=powershell.exe"

"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

echo.
echo Watcher stopped or failed. Exit code: %ERRORLEVEL%
pause
