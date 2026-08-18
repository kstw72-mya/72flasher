@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

adb start-server >nul 2>&1
adb get-state >nul 2>&1
if errorlevel 1 exit /b 1

if not exist "preload.so" exit /b 1

adb shell rm -rf /data/local/tmp/* >nul 2>&1
adb push preload.so /data/local/tmp/preload.so >nul 2>&1
if errorlevel 1 exit /b 1

adb shell chmod 755 /data/local/tmp/preload.so >nul 2>&1
if errorlevel 1 exit /b 1

set "count=0"
:get_root
set /a count+=1
:: The garnet payload is triggered through /system/bin/true, matching TOOL.py.
adb shell "LD_PRELOAD=/data/local/tmp/preload.so /system/bin/true" >nul 2>&1
timeout /t 2 /nobreak >nul

for /f "delims=" %%i in ('adb shell "su -c id" 2^>^&1') do (
    echo %%i | findstr /i "uid=0(root)" >nul
    if !errorlevel! equ 0 goto finish
)

if !count! geq 30 (
    exit /B 1
)
timeout /t 1 /nobreak >nul
goto get_root

:finish
echo ===================================================
echo [+] Temp Root environment is ready!
echo ===================================================
exit /B 0
