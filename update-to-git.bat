@echo off
setlocal
title Push local updates to GitHub
cd /d "%~dp0"

if not exist ".git" (
    echo This folder is not a git repository.
    echo Clone the repository with git first, then run this file.
    pause
    exit /b 1
)

for /f "delims=" %%B in ('git branch --show-current') do set "BRANCH=%%B"
if "%BRANCH%"=="" set "BRANCH=main"

echo Syncing with GitHub before pushing...
echo Branch: %BRANCH%
echo.

git pull --rebase --autostash origin "%BRANCH%"
if errorlevel 1 (
    echo.
    echo Pull failed. Fix the message above, then run this again.
    pause
    exit /b 1
)

git add -A
git diff --cached --quiet
if not errorlevel 1 (
    echo.
    echo No local changes to push.
    pause
    exit /b 0
)

for /f "delims=" %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "STAMP=%%T"

git commit -m "Update portable mirror package %STAMP%"
if errorlevel 1 (
    echo.
    echo Commit failed. Check the message above.
    pause
    exit /b 1
)

git push origin "%BRANCH%"
if errorlevel 1 (
    echo.
    echo Push failed. Check the message above.
    pause
    exit /b 1
)

echo.
echo Done. Local changes are pushed to GitHub.
pause
