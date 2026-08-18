@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

if not exist "ghostlock" exit /b 1
if not exist "ksud" exit /b 1
if not exist "ksu.APK" exit /b 1

adb get-state >nul 2>&1
if errorlevel 1 exit /b 1

adb shell rm -rf /data/local/tmp/* >nul 2>&1
if errorlevel 1 exit /b 1

adb install -r "ksu.APK" >nul 2>&1
if errorlevel 1 exit /b 1

adb push "ksud" /data/local/tmp/ksud >nul 2>&1
if errorlevel 1 exit /b 1
adb shell chmod 755 /data/local/tmp/ksud >nul 2>&1
if errorlevel 1 exit /b 1

adb push "ghostlock" /data/local/tmp/ghostlock >nul 2>&1
if errorlevel 1 exit /b 1
adb shell chmod 755 /data/local/tmp/ghostlock >nul 2>&1
if errorlevel 1 exit /b 1

if exist "offsets.json" (
    adb push "offsets.json" /data/local/tmp/offsets.json >nul 2>&1
    if errorlevel 1 exit /b 1
)

adb shell /data/local/tmp/ghostlock >nul 2>&1
if errorlevel 1 exit /b 1

for /f "delims=" %%i in ('adb shell "su -c id" 2^>^&1') do (
    echo %%i | findstr "uid=0(root)" >nul
    if !errorlevel! equ 0 (
        exit /b 0
    )
)

exit /b 1
