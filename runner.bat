@echo off
rem Double-click this file to play Defense in Depth.
cd /d "%~dp0"

if not exist "builds\windows\DefenseInDepth.exe" (
    echo.
    echo Defense in Depth could not start: the game file is missing.
    echo It should be here: %~dp0builds\windows\DefenseInDepth.exe
    echo.
    echo Please download the full game folder again, or ask whoever sent it to you.
    echo.
    pause
    exit /b 1
)

start "" "builds\windows\DefenseInDepth.exe"
