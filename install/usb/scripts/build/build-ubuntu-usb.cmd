@echo off
setlocal EnableExtensions

REM ============================================================
REM LISA Edge - Build a complete installer USB (Windows)
REM ============================================================
REM One-pass pipeline (replaces Rufus):
REM   1. fetch   platform\windows\fetch-ubuntu-iso.ps1
REM   2. write   platform\windows\create-usb-disk.ps1
REM   3. inject  ..\prepare\prepare-<profile>-usb.cmd
REM
REM The result boots UEFI systems only (ZimaBoard 2, NUC, ...).
REM Run from an elevated (Administrator) prompt.
REM ============================================================

set "SCRIPT_DIR=%~dp0"
set "PLATFORM_DIR=%SCRIPT_DIR%platform\windows"
set "PREPARE_DIR=%SCRIPT_DIR%..\prepare"

set "PROFILE=%~1"
if "%PROFILE%"=="" goto :Usage
if /I "%PROFILE%"=="help"   goto :Usage
if /I "%PROFILE%"=="-h"     goto :Usage
if /I "%PROFILE%"=="--help" goto :Usage
if /I "%PROFILE%"=="list" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PLATFORM_DIR%\create-usb-disk.ps1" -List
    exit /b %ERRORLEVEL%
)
if /I "%PROFILE%"=="production" goto :ProfileOk
if /I "%PROFILE%"=="rescue"     goto :ProfileOk
echo ERROR: first argument must be 'production', 'rescue', or 'list'.
echo.
goto :Usage
:ProfileOk

set "DISKNUM="
set "ISO_PATH="
set "RELEASE="
set "OPT_YES="
set "OPT_DRYRUN="

shift
:ParseArgs
if "%~1"=="" goto :ArgsDone
echo %~1| findstr /r "^[0-9][0-9]*$" >nul && ( set "DISKNUM=%~1" & shift & goto :ParseArgs )
if /I "%~1"=="--iso"     ( set "ISO_PATH=%~2" & shift & shift & goto :ParseArgs )
if /I "%~1"=="--release" ( set "RELEASE=%~2" & shift & shift & goto :ParseArgs )
if /I "%~1"=="--yes"     ( set "OPT_YES=1" & shift & goto :ParseArgs )
if /I "%~1"=="-y"        ( set "OPT_YES=1" & shift & goto :ParseArgs )
if /I "%~1"=="--dry-run" ( set "OPT_DRYRUN=1" & shift & goto :ParseArgs )
echo ERROR: unknown argument: %~1
exit /b 2
:ArgsDone

REM ------------------------------------------------------------
REM Interactive disk selection when no disk number was given.
REM ------------------------------------------------------------
if defined DISKNUM goto :HaveDisk
if defined OPT_YES (
    echo ERROR: --yes requires an explicit disk number ^(nothing is guessed^).
    exit /b 2
)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PLATFORM_DIR%\create-usb-disk.ps1" -List
set /p DISKNUM=Enter the target USB disk number: 
if defined DISKNUM set "DISKNUM=%DISKNUM: =%"
if not defined DISKNUM (
    echo ERROR: no disk selected; aborting with no changes.
    exit /b 2
)
echo %DISKNUM%| findstr /r "^[0-9][0-9]*$" >nul || (
    echo ERROR: disk number must be numeric: %DISKNUM%
    exit /b 2
)
:HaveDisk

REM ------------------------------------------------------------
REM Step 1/3: obtain a verified ISO.
REM ------------------------------------------------------------
if defined ISO_PATH (
    echo ==^> [1/3] Using provided ISO: %ISO_PATH% ^(fetch skipped^)
    if not exist "%ISO_PATH%" (
        echo ERROR: ISO not found: %ISO_PATH%
        exit /b 2
    )
    goto :FetchDone
)
echo.
echo ==^> [1/3] Downloading and verifying the Ubuntu Server ISO
set "FETCH_ARGS="
if defined RELEASE set "FETCH_ARGS=-Release "%RELEASE%""
for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%PLATFORM_DIR%\fetch-ubuntu-iso.ps1" %FETCH_ARGS%`) do set "ISO_PATH=%%I"
if not defined ISO_PATH (
    echo ERROR: ISO download/verification failed.
    exit /b 1
)
if not exist "%ISO_PATH%" (
    echo ERROR: fetch reported "%ISO_PATH%" but the file does not exist.
    exit /b 1
)
:FetchDone

REM ------------------------------------------------------------
REM Step 2/3: write the bootable USB.
REM ------------------------------------------------------------
echo.
echo ==^> [2/3] Writing the bootable installer USB ^(disk %DISKNUM%^)
set "CREATE_FLAGS="
if defined OPT_YES    set "CREATE_FLAGS=%CREATE_FLAGS% -Force"
if defined OPT_DRYRUN set "CREATE_FLAGS=%CREATE_FLAGS% -DryRun"
set "USB_LETTER="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%PLATFORM_DIR%\create-usb-disk.ps1" -DiskNumber %DISKNUM% -IsoPath "%ISO_PATH%" %CREATE_FLAGS%`) do set "USB_LETTER=%%I"

if defined OPT_DRYRUN (
    echo.
    echo ==^> [3/3] Skipped ^(dry-run^): would inject the '%PROFILE%' autoinstall profile
    echo Dry-run finished; no changes were made.
    exit /b 0
)
if not defined USB_LETTER (
    echo ERROR: USB creation failed ^(no drive letter reported^).
    exit /b 1
)
if not exist "%USB_LETTER%\" (
    echo ERROR: USB creation reported %USB_LETTER% but the drive is not accessible.
    exit /b 1
)

REM ------------------------------------------------------------
REM Step 3/3: inject the autoinstall profile.
REM ------------------------------------------------------------
echo.
echo ==^> [3/3] Injecting the LISA Edge '%PROFILE%' autoinstall profile
set "PREP_FLAGS="
if defined OPT_YES set "PREP_FLAGS=--yes"
if /I "%PROFILE%"=="production" (
    call "%PREPARE_DIR%\prepare-production-usb.cmd" %PREP_FLAGS% %USB_LETTER%
) else (
    call "%PREPARE_DIR%\prepare-rescue-usb.cmd" %USB_LETTER%
)
if errorlevel 1 (
    echo ERROR: autoinstall injection failed ^(exit code %ERRORLEVEL%^).
    exit /b 1
)

echo.
echo Done. Eject %USB_LETTER% safely before removing the USB.
echo Boot the target machine from this USB ^(UEFI^) and confirm the installer
echo targets the correct disk.
exit /b 0

:Usage
echo LISA Edge - Build a complete installer USB ^(Windows^)
echo.
echo Usage:
echo   build-ubuntu-usb.cmd ^<production^|rescue^> [disk-number] [options]
echo   build-ubuntu-usb.cmd list
echo.
echo When no disk number is given, USB disks are listed and you are asked
echo to pick one. With --yes the disk number is mandatory.
echo.
echo Options:
echo   --iso ^<path^>       Use an already-downloaded ISO ^(skips the fetch step^).
echo   --release ^<series^> Release series from config\ubuntu-releases.json.
echo   --yes ^| -y         Non-interactive: skip confirmations.
echo   --dry-run          Validate everything, change nothing.
echo.
echo Steps: download + verify the Ubuntu Server ISO, write a bootable UEFI
echo USB ^(no Rufus needed^), then inject the LISA Edge autoinstall profile.
echo Run from an elevated ^(Administrator^) prompt.
echo.
echo Find your USB disk number first:
echo   build-ubuntu-usb.cmd list
exit /b 2
