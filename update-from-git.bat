@echo off
setlocal
title Update local files from GitHub
cd /d "%~dp0"

if not exist ".git" (
    echo This folder is not a git repository.
    echo Clone the repository with git first, then run this file.
    pause
    exit /b 1
)

for /f "delims=" %%B in ('git branch --show-current') do set "BRANCH=%%B"
if "%BRANCH%"=="" set "BRANCH=main"

echo Updating local files from GitHub...
echo Branch: %BRANCH%
echo.

git pull --rebase --autostash origin "%BRANCH%"
if errorlevel 1 (
    echo.
    echo Update failed. Check the message above.
    pause
    exit /b 1
)

echo.
echo Done. Local files are up to date.
pause
