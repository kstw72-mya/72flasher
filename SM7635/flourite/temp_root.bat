@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo [*] Pushing required files to device...
adb push exploit /data/local/tmp/exploit
adb push su /data/local/tmp/su
adb push Eng_abl.elf /data/local/tmp/abl.elf

echo [*] Setting permissions...
adb shell chmod 755 /data/local/tmp/exploit /data/local/tmp/su

echo [*] Executing exploit initially...
adb shell /data/local/tmp/exploit

echo [*] Checking Root Access...
set "count=0"
:check_root
adb shell "/data/local/tmp/su -c 'id'" 2>nul | findstr /i "uid=0(root)" >nul
if %errorlevel% equ 0 (
    echo [+] Root access obtained successfully!
    goto set_permissive
)
set /a count+=1
if %count% geq 10 (
    echo [-] Error: Failed to get root access after 10 attempts.
    exit /B 1
)
echo [*] Retrying exploit (Attempt %count%/10)...
adb shell /data/local/tmp/exploit
timeout /t 1 /nobreak >nul
goto check_root

:set_permissive
echo [*] Checking and setting SELinux to Permissive...
set "count_2=0"
:check_selinux
adb shell "/data/local/tmp/su -c 'getenforce'" 2>nul | findstr /i "Permissive" >nul
if %errorlevel% equ 0 (
    echo [+] SELinux is now Permissive!
    goto finish
)
set /a count_2+=1
if %count_2% geq 10 (
    echo [-] Error: Failed to set SELinux to Permissive after 10 attempts.
    exit /B 1
)
echo [*] Retrying exploit for SELinux (Attempt %count_2%/10)...
adb shell /data/local/tmp/exploit
timeout /t 1 /nobreak >nul
goto check_selinux

:finish
echo ===================================================
echo [+] Temp Root and Permissive environment are ready!
echo ===================================================
exit /B 0