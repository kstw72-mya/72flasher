@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

if not exist "preload.so" (
    echo ERROR: preload.so not found.
    exit /b 1
)
adb start-server >nul 2>&1
adb get-state >nul 2>&1
if errorlevel 1 (
    echo ERROR: Device not found.
    exit /b 1
)

echo Running Temp Root....
adb shell rm -rf /data/local/tmp/* >nul 2>&1
if errorlevel 1 (
    echo ERROR: Failed to prepare device.
    exit /b 1
)

adb push preload.so /data/local/tmp/preload.so >nul 2>&1
if errorlevel 1 (
    echo ERROR: Failed to push preload.
    exit /b 1
)

adb shell chmod 755 /data/local/tmp/preload.so >nul 2>&1
if errorlevel 1 (
    echo ERROR: Failed to set permissions.
    exit /b 1
)

set "count=0"
:get_root
set /a count+=1
:: The GUI uses the purna_borno worker; this batch keeps the same
:: LD_PRELOAD fallback for manual execution.
adb shell "LD_PRELOAD=/data/local/tmp/preload.so /system/bin/true" >nul 2>&1

set "root_found="
for /f "delims=" %%i in ('adb shell "su -c id" 2^>^&1') do (
    echo %%i | findstr /i "uid=0(root)" >nul
    if !errorlevel! equ 0 set "root_found=1"
)

if defined root_found goto finish
if !count! geq 30 (
    echo ERROR: Root access not obtained.
    exit /b 1
)

timeout /t 1 /nobreak >nul
goto get_root

:finish
echo Temp Root completed successfully.
exit /b 0
