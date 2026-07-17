@echo off
setlocal EnableExtensions

REM ============================================================
REM LISA Edge operator command (Windows)
REM ============================================================
REM Day-0 companion to the Unix ./lisa-edge CLI: prepares
REM installation media and configuration from a Windows
REM workstation BEFORE any LISA Edge server exists.
REM
REM Runtime operations (setup, bootstrap, deploy, backup, ...)
REM run on the Linux host itself via ./lisa-edge.
REM ============================================================

set "EDGE_REPO=%~dp0"
if "%EDGE_REPO:~-1%"=="\" set "EDGE_REPO=%EDGE_REPO:~0,-1%"

set "USB_BUILD=%EDGE_REPO%\install\usb\scripts\build\build-ubuntu-usb.cmd"
set "USB_PRODUCTION=%EDGE_REPO%\install\usb\scripts\prepare\prepare-production-usb.cmd"
set "USB_RESCUE=%EDGE_REPO%\install\usb\scripts\prepare\prepare-rescue-usb.cmd"

REM ------------------------------------------------------------
REM Colors (ANSI escape sequences). Enabled only when the console
REM is known to support them; honors NO_COLOR (https://no-color.org).
REM Windows Terminal / ConEmu / ANSICON advertise support via env
REM vars; classic conhost needs HKCU\Console VirtualTerminalLevel=1.
REM ------------------------------------------------------------
set "C_TITLE=" & set "C_SECTION=" & set "C_CMD=" & set "C_ERR=" & set "C_DIM=" & set "C_RESET="
set "COLOR_OK="
if defined WT_SESSION set "COLOR_OK=1"
if /I "%ConEmuANSI%"=="ON" set "COLOR_OK=1"
if defined ANSICON set "COLOR_OK=1"
if not defined COLOR_OK reg query "HKCU\Console" /v VirtualTerminalLevel 2>nul | find "0x1" >nul && set "COLOR_OK=1"
if defined NO_COLOR set "COLOR_OK="
if not defined COLOR_OK goto :ColorsDone
REM Capture the raw ESC (0x1B) character via the prompt $E token.
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
set "C_TITLE=%ESC%[1;96m"
set "C_SECTION=%ESC%[1;93m"
set "C_CMD=%ESC%[1;92m"
set "C_ERR=%ESC%[1;91m"
set "C_DIM=%ESC%[90m"
set "C_RESET=%ESC%[0m"
:ColorsDone

if "%~1"=="" goto :Usage

set "COMMAND=%~1"

if /I "%COMMAND%"=="help"   goto :Usage
if /I "%COMMAND%"=="-h"     goto :Usage
if /I "%COMMAND%"=="--help" goto :Usage
if /I "%COMMAND%"=="usb"    goto :Usb
if /I "%COMMAND%"=="config" goto :Config

REM Linux-host commands: point the operator at the right tool.
for %%C in (setup configure bootstrap deploy stop update health status diagnostics backup restore rescue service) do (
    if /I "%COMMAND%"=="%%C" goto :LinuxOnly
)

echo %C_ERR%ERROR:%C_RESET% Unknown command %C_CMD%%COMMAND%%C_RESET%
echo.
call :Usage
exit /b 2

REM ------------------------------------------------------------
REM usb production ^| usb rescue
REM ------------------------------------------------------------
:Usb
set "TARGET=%~2"
if "%TARGET%"=="" (
    echo %C_ERR%ERROR:%C_RESET% usb requires 'list', 'build', or 'prepare'.
    echo.
    call :Usage
    exit /b 2
)

if /I "%TARGET%"=="list" (
    if not exist "%USB_BUILD%" (
        echo %C_ERR%ERROR:%C_RESET% Missing implementation: %USB_BUILD%
        echo.
        exit /b 2
    )
    call "%USB_BUILD%" list
    exit /b %ERRORLEVEL%
)

if /I "%TARGET%"=="prepare" (
    set "PREP_PROFILE=%~3"
    call :CollectArgs3 %*
    goto :UsbPrepare
)

call :CollectArgs %*

if /I "%TARGET%"=="build" (
    if not exist "%USB_BUILD%" (
        echo %C_ERR%ERROR:%C_RESET% Missing implementation: %USB_BUILD%
        echo.
        exit /b 2
    )
    call "%USB_BUILD%" %FWD_ARGS%
    exit /b %ERRORLEVEL%
)

if /I "%TARGET%"=="production" (
    if not exist "%USB_PRODUCTION%" (
        echo %C_ERR%ERROR:%C_RESET% Missing implementation: %USB_PRODUCTION%
        echo.
        exit /b 2
    )
    call "%USB_PRODUCTION%" %FWD_ARGS%
    exit /b %ERRORLEVEL%
)

if /I "%TARGET%"=="rescue" (
    if not exist "%USB_RESCUE%" (
        echo %C_ERR%ERROR:%C_RESET% Missing implementation: %USB_RESCUE%
        echo.
        exit /b 2
    )
    call "%USB_RESCUE%" %FWD_ARGS%
    exit /b %ERRORLEVEL%
)

echo %C_ERR%ERROR:%C_RESET% Unknown USB target: %TARGET%
echo.
call :Usage
exit /b 2

REM ------------------------------------------------------------
REM config production - generate/validate autoinstall user-data
REM without touching any USB drive.
REM ------------------------------------------------------------
:Config
set "TARGET=%~2"
if "%TARGET%"=="" set "TARGET=production"

if /I "%TARGET%"=="production" (
    if not exist "%USB_PRODUCTION%" (
        echo %C_ERR%ERROR:%C_RESET% Missing implementation: %USB_PRODUCTION%
        echo.
        exit /b 2
    )
    call "%USB_PRODUCTION%" --config-only
    exit /b %ERRORLEVEL%
)

echo %C_ERR%ERROR:%C_RESET% 'config' currently supports only the production profile.
echo.
echo The rescue user-data template is edited by hand; see:
echo   %C_DIM%%EDGE_REPO%\install\usb\config\rescue\user-data.template%C_RESET%
exit /b 2

REM ------------------------------------------------------------
REM usb prepare production ^| rescue - inject-only workflow
REM ------------------------------------------------------------
:UsbPrepare
if /I "%PREP_PROFILE%"=="production" (
    if not exist "%USB_PRODUCTION%" (
        echo %C_ERR%ERROR:%C_RESET% Missing implementation: %USB_PRODUCTION%
        echo.
        exit /b 2
    )
    call "%USB_PRODUCTION%" %FWD_ARGS%
    exit /b %ERRORLEVEL%
)
if /I "%PREP_PROFILE%"=="rescue" (
    if not exist "%USB_RESCUE%" (
        echo %C_ERR%ERROR:%C_RESET% Missing implementation: %USB_RESCUE%
        echo.
        exit /b 2
    )
    call "%USB_RESCUE%" %FWD_ARGS%
    exit /b %ERRORLEVEL%
)
echo %C_ERR%ERROR:%C_RESET% usb prepare requires 'production' or 'rescue'.
echo.
call :Usage
exit /b 2

REM ------------------------------------------------------------
REM Skip the first two tokens (command + target) and forward the
REM rest verbatim. NOTE: in cmd, %%* ignores shift, so collect
REM the remaining arguments manually.
REM ------------------------------------------------------------
:CollectArgs
set "FWD_ARGS="
shift
shift
:CollectArgsLoop
if "%~1"=="" exit /b 0
set "FWD_ARGS=%FWD_ARGS% %1"
shift
goto :CollectArgsLoop

REM Same as :CollectArgs but skips three tokens (command + target + profile).
:CollectArgs3
set "FWD_ARGS="
shift
shift
shift
:CollectArgs3Loop
if "%~1"=="" exit /b 0
set "FWD_ARGS=%FWD_ARGS% %1"
shift
goto :CollectArgs3Loop

REM ------------------------------------------------------------
:LinuxOnly
echo %C_SECTION%'%COMMAND%'%C_RESET% runs on the LISA Edge host itself, not from Windows.
echo.
echo On the Linux host:
echo   %C_CMD%sudo ./lisa-edge %COMMAND%%C_RESET%
echo.
echo From Windows, this tool covers day-0 preparation only:
echo   %C_CMD%lisa-edge usb production%C_RESET% ^| %C_CMD%usb rescue%C_RESET% ^| %C_CMD%config%C_RESET%
exit /b 2

REM ------------------------------------------------------------
:Usage
echo %C_TITLE%LISA Edge operator command (Windows, day-0 preparation)%C_RESET%
echo.
echo %C_SECTION%Usage:%C_RESET%
echo   %C_CMD%lisa-edge%C_RESET% ^<command^> [arguments]
echo.
echo %C_SECTION%Installation media (no LISA Edge server required):%C_RESET%
echo   %C_CMD%usb list%C_RESET%                          List USB disks ^(number, drive letter,
echo                                     name, size^) to identify the target
echo   %C_CMD%usb build%C_RESET% ^<profile^> [disk-number]  Download Ubuntu, write a bootable USB
echo                                     ^(no Rufus needed^), inject the profile.
echo                                     %C_DIM%(asks which disk when number omitted)%C_RESET%
echo   %C_CMD%usb prepare production%C_RESET% [options] [drive]  Inject the production profile
echo                                     %C_DIM%(options: --auto-detect ^| -a, --dry-run,%C_RESET%
echo                                      %C_DIM%--config-only, --yes ^| -y)%C_RESET%
echo   %C_CMD%usb prepare rescue%C_RESET% ^<drive^>        Inject the rescue profile
echo.
echo %C_SECTION%Configuration:%C_RESET%
echo   %C_CMD%config%C_RESET% [production]               Generate or validate the production
echo                                     autoinstall user-data (config wizard,
echo                                     no USB required)
echo.
echo %C_SECTION%General:%C_RESET%
echo   %C_CMD%help%C_RESET%                              Show this help
echo.
echo %C_SECTION%Examples:%C_RESET%
echo   %C_DIM%lisa-edge usb list%C_RESET%
echo   %C_DIM%lisa-edge usb build production%C_RESET%
echo   %C_DIM%lisa-edge usb build production 2 --dry-run%C_RESET%
echo   %C_DIM%lisa-edge usb prepare production --auto-detect%C_RESET%
echo   %C_DIM%lisa-edge usb prepare rescue E:%C_RESET%
echo   %C_DIM%lisa-edge config%C_RESET%
echo.
echo Everything after installation (setup, bootstrap, deploy, backup,
echo r