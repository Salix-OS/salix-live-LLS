@echo off
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION
cd /d %~dp0

set VER=1.3
set AUTHOR=Pontvieux Cyrille - jrd@enialis.net
set LICENCE=GPL v3+
title install-on-USB v%VER
goto start

:version
  echo install-on-USB v%VER% by %AUTHOR%
  echo Licence : %LICENCE%
  echo -^> Install grub2 on an USB key using the USB key itself.
  goto :EOF

:usage
  call :version
  echo.
  echo usage: install-on-USB.sh [/?] [/v]
  goto :EOF

:chk_grub_files
  setlocal
  set DIR=%~1
  if not exist "%DIR%\grub_mbr" (
    echo Error: %DIR% doesn't contain grub_mbr file
    exit /b 3
  )
  if not exist "%DIR%\grub_post_mbr_gap" (
    echo Error: %DIR% doesn't contain grub_post_mbr_gap file
    exit /b 3
  )
  endlocal
  goto :EOF

:chk_post_mbr_gap
  setlocal
  set DEVICE=%~1
  set DIR=%~2
  set DD="%DIR%\dd.exe"
  set OD="%DIR%\od.exe"
  set L2D="%DIR%\letter2disk.vbs"
  if not exist %DD% (
    echo Error: %DIR% doesn't contain dd.exe file
    exit /b 4
  )
  if not exist %OD% (
    echo Error: %DIR% doesn't contain od.exe file
    exit /b 4
  )
  if not exist %L2D% (
    echo Error: %DIR% doesn't contain letter2disk.vbs file
    exit /b 4
  )
  rem Search for informations of the mounted drive letter
  for /f "delims=" %%r in ('cscript //nologo "%L2D%" %DEVICE%') do set diskinfos=%%r
  for /f "tokens=1 delims=:" %%r in ("%diskinfos%") do set diskindex=%%r
  for /f "tokens=3 delims=:" %%r in ("%diskinfos%") do set disktype=%%r
  call :chk_usb "%disktype%" "%diskindex%"
  if %errorlevel% GTR 0 (
    endlocal
    exit /b %errorlevel%
  )
  set disk=\\.\PHYSICALDRIVE%diskindex%
  rem Read MBR.
  rem Windows has restriction on reading/writing to a physical drive: you must read/write only using sectors (512 bytes).
  "%DD%" if=%disk% of=%TEMP%\mbr count=1 bs=512 2>nul
  rem Trying with 'dd' and 'od' to read the 4 LBA bytes of the first partition
  rem 454 = 446 + 1 (active?) + 3 (CHS start address) + 1 (type) + 3 (CHS end address)
  "%DD%" if=%TEMP%\mbr of=%TEMP%\firstsector count=4 bs=1 skip=454 2>nul
  for /f "delims=" %%r in ('"%OD%" -td4 -An %TEMP%\firstsector') do set /a GAP=%%r
  del %TEMP%\mbr %TEMP%\firstsector
  if %GAP% LSS 63 (
    echo Error: the post MBR gap is missing or not large enough [63 sectors]. >&2
    echo   Yours appears to be of %GAP% sectors. >&2
    echo Suggestion: slightly move the first partition %disk%\Partition1 to reach the gap size. >&2
    exit /b 5
  )
  endlocal
  goto :EOF

:install_grub2
  setlocal
  set DEVICE=%~1
  set DIR=%~2
  set DD="%DIR%\dd.exe"
  set L2D="%DIR%\letter2disk.vbs"
  set GRUB_MBR="%DIR%\grub_mbr"
  set GRUB_POST_MBR="%DIR%\grub_post_mbr_gap"
  rem Search for informations of the mounted drive letter
  for /f "delims=" %%r in ('cscript //nologo "%L2D%" %DEVICE%') do set diskinfos=%%r
  for /f "tokens=1 delims=:" %%r in ("%diskinfos%") do set diskindex=%%r
  for /f "tokens=3 delims=:" %%r in ("%diskinfos%") do set disktype=%%r
  call :chk_usb "%disktype%" "%diskindex%"
  if %errorlevel% GTR 0 (
    endlocal
    exit /b %errorlevel%
  )
  set disk=\\.\PHYSICALDRIVE%diskindex%
  set res=n
  echo Warning: grub2 is about to be installed in %disk% (%DEVICE%)
  set /p res=Do you want to continue? [y/N] 
  if not "%res%" == "y" goto :EOF
  rem Windows has restriction on reading/writing to a physical drive: you must read/write only using sectors (512 bytes) and seek is not working.
  "%DD%" if=%disk% of=%TEMP%\64s count=64 bs=512 2>nul
  "%DD%" if=%GRUB_MBR% of=%TEMP%\64s count=440 bs=1 conv=notrunc 2>nul
  "%DD%" if=%GRUB_POST_MBR% of=%TEMP%\64s count=63 bs=512 seek=1 conv=notrunc 2>nul
  "%DD%" if=%TEMP%\64s of=%disk% count=64 bs=512 conv=notrunc
  del %TEMP%\64s
  endlocal
  goto :EOF

:chk_usb
  setlocal
  set disktype=%~1
  set diskindex=%~2
  if "%disktype%" == "USB" (
    endlocal
    goto :EOF
  )
  set res=n
  set /p res=Disk #%diskindex% is not USB type, do you want to continue? [y/N] 
  if not "%res%" == "y" (
    endlocal
    exit /b 1
  )
  endlocal
  goto :EOF

:start
  if _%1 == _/v goto version
  if _%1 == _/? goto usage
  
  if "%TEMP%" == "" set TEMP=.
  set DRIVE=%~d0
  set DIR=%~dp0
  echo Checking for GRUB2 files...
  call :chk_grub_files "%DIR%"
  if %errorlevel% GTR 0 goto end
  echo Checking for post-MBR gap...
  call :chk_post_mbr_gap "%DRIVE%" "%DIR%"
  if %errorlevel% GTR 0 goto end
  echo Installing GRUB2...
  call :install_grub2 "%DRIVE%" "%DIR%"
  if %errorlevel% GTR 0 goto end
  echo GRUB2 installed successfully!
:end
  pause
