@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo.
echo  SELinux Permissive - Adreno A7xx
echo  ---------------------------------
echo.

set "ADB=%~dp0tools\adb.exe"
set "MAGISKBOOT=%~dp0tools\magiskboot.exe"
set "CF=%~dp0tools\cf"

if not exist "%ADB%" ( echo adb not found & pause & exit /b 1 )
if not exist "%MAGISKBOOT%" ( echo magiskboot not found & pause & exit /b 1 )
if not exist "%CF%" ( echo cf not found & pause & exit /b 1 )

:: step1 - unpack boot.img
echo  [step1] drag boot.img here:
set /p "BOOT_IMG=> "
set "BOOT_IMG=%BOOT_IMG:"=%"
if not defined BOOT_IMG ( echo no input & pause & exit /b 1 )
if not exist "!BOOT_IMG!" ( echo file not found & pause & exit /b 1 )

echo  unpacking...
if not exist "%~dp0output" mkdir "%~dp0output"
pushd "%~dp0output"
"%MAGISKBOOT%" unpack -h "!BOOT_IMG!" 2>&1
if not exist "kernel" "%MAGISKBOOT%" unpack "!BOOT_IMG!" 2>&1
popd
if not exist "%~dp0output\kernel" ( echo unpack failed & pause & exit /b 1 )
echo  kernel ok
echo.

:: step2 - find selinux_state
echo  [step2] parsing kallsyms...
"%~dp0tools\kallsyms_finder.exe" "%~dp0output\kernel" "%~dp0output"

if not exist "%~dp0output\kallsyms_table.txt" ( echo selinux_state not found & pause & exit /b 1 )
set "VA="
for /f "usebackq delims=" %%a in ("%~dp0output\kallsyms_table.txt") do set "VA=%%a"
if not defined VA ( echo addr empty & pause & exit /b 1 )
echo  selinux_state = %VA%
echo.

:: step3 - connect + exploit
echo  [step3] waiting for device...
:wait
"%ADB%" devices 2>nul | findstr /r /c:"device$" >nul
if errorlevel 1 ( timeout /t 3 /nobreak >nul & goto wait )
for /f "tokens=*" %%m in ('"%ADB%" shell getprop ro.product.model 2^>nul') do echo  model: %%m
for /f "tokens=*" %%s in ('"%ADB%" shell getenforce 2^>nul') do echo  selinux: %%s
echo.

for /f "tokens=*" %%s in ('"%ADB%" shell getenforce 2^>nul') do set "CUR=%%s"
echo !CUR! | findstr /i "Permissive" >nul && ( echo  already permissive & goto done )

"%ADB%" push "%CF%" /data/local/tmp/cf >nul
"%ADB%" shell chmod +x /data/local/tmp/cf

set "ATTEMPT=0"

:retry
set /a ATTEMPT+=1
echo.
echo  attempt !ATTEMPT!  S_VATUAL=%VA%
"%ADB%" shell "export S_VATUAL=%VA% && cd /data/local/tmp && ./cf 2>&1 | tee /data/local/tmp/cf_log" 2>&1

timeout /t 3 /nobreak >nul

:: check if device is still online
"%ADB%" devices 2>nul | findstr /r /c:"device$" >nul
set "DEV_ERR=!errorlevel!"
if !DEV_ERR! neq 0 echo  device disconnected, waiting for it to come back...
if !DEV_ERR! neq 0 goto do_reboot

timeout /t 8 /nobreak >nul

set "SE="
for /f "tokens=*" %%s in ('"%ADB%" shell getenforce 2^>nul') do set "SE=%%s"
echo  selinux: !SE!
echo !SE! | findstr /i "Permissive" >nul
if !errorlevel! equ 0 goto ok

:: not permissive, reboot and retry
echo  not permissive, rebooting device...
start "" /b "%ADB%" shell reboot
timeout /t 5 /nobreak >nul

:do_reboot
:: kill adb server to get clean state
"%ADB%" kill-server 2>nul
timeout /t 3 /nobreak >nul

:rb_wait
"%ADB%" devices 2>nul | findstr /r /c:"device$" >nul
if !errorlevel! equ 0 goto rb_online
echo  waiting for device...
timeout /t 5 /nobreak >nul
goto rb_wait

:rb_online
echo  device detected, waiting 10s for boot...
timeout /t 10 /nobreak >nul
echo  device back online

:: repush and retry
"%ADB%" push "%CF%" /data/local/tmp/cf >nul 2>&1
"%ADB%" shell chmod +x /data/local/tmp/cf >nul 2>&1
goto retry

:ok
echo.
echo  success on attempt !ATTEMPT!
goto done

:done
echo.
"%ADB%" shell rm -f /data/local/tmp/cf >nul 2>&1
if exist "%~dp0output" rd /s /q "%~dp0output" >nul 2>&1
pause
