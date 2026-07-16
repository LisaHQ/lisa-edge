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

set "USB_PRODUCTION=%EDGE_REPO%\install\usb\production\scripts\prepare-ubuntu-usb.bat"
set "USB_RESCUE=%EDGE_REPO%\install\usb\rescue\prepare-ubuntu-rescue-usb.bat"

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

echo ERROR: Unknown command: %COMMAND%
call :Usage
exit /b 2

REM ------------------------------------------------------------
REM usb production ^| usb rescue
REM ------------------------------------------------------------
:Usb
set "TARGET=%~2"
if "%TARGET%"=="" (
    echo ERROR: usb requires 'production' or 'rescue'.
    call :Usage
    exit /b 2
)

call :CollectArgs %*

if /I "%TARGET%"=="production" (
    if not exist "%USB_PRODUCTION%" (
        echo ERROR: Missing implementation: %USB_PRODUCTION%
        exit /b 2
    )
    call "%USB_PRODUCTION%" %FWD_ARGS%
    exit /b %ERRORLEVEL%
)

if /I "%TARGET%"=="rescue" (
    if not exist "%USB_RESCUE%" (
        echo ERROR: Missing implementation: %USB_RESCUE%
        exit /b 2
    )
    call "%USB_RESCUE%" %FWD_ARGS%
    exit /b %ERRORLEVEL%
)

echo ERROR: Unknown USB target: %TARGET%
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
        echo ERROR: Missing implementation: %USB_PRODUCTION%
        exit /b 2
    )
    call "%USB_PRODUCTION%" --config-only
    exit /b %ERRORLEVEL%
)

echo ERROR: 'config' currently supports only the production profile.
echo The rescue user-data template is edited by hand; see:
echo   %EDGE_REPO%\install\usb\rescue\autoinstall\user-data.template
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

REM ------------------------------------------------------------
:LinuxOnly
echo '%COMMAND%' runs on the LISA Edge host itself, not from Windows.
echo.
echo On the Linux host:
echo   sudo ./lisa-edge %COMMAND%
echo.
echo From Windows, this tool covers day-0 preparation only:
echo   lisa-edge usb production ^| usb rescue ^| config
exit /b 2

REM ------------------------------------------------------------
:Usage
echo LISA Edge operator command (Windows, day-0 preparation)
echo.
echo Usage:
echo   lisa-edge ^<command^> [arguments]
echo.
echo Installation media (no LISA Edge server required):
echo   usb production [options] [drive]  Prepare a production installer USB
echo                                     (options: --auto-detect ^| -a, --dry-run,
echo                                      --config-only, --yes ^| -y)
echo   usb rescue ^<drive^>                Prepare a rescue installer USB
echo.
echo Configuration:
echo   config [production]               Generate or validate the production
echo                                     autoinstall user-data (config wizard,
echo                                     no USB required)
echo.
echo General:
echo   help                              Show this help
echo.
echo Examples:
echo   lisa-edge usb production --auto-detect
echo   lisa-edge usb production E:
echo   lisa-edge usb rescue E:
echo   lisa-edge config
echo.
echo Everything after installation (setup, bootstrap, deploy, backup,
echo restore, rescue tooling) runs on the Linux host via ./lisa-edge.
exit /b 0
