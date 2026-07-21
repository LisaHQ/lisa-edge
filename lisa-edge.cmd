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
set "C_RESET=" & set "C_TITLE=" & set "C_SECTION="
set "C_EXE=" & set "C_CMD=" & set "C_CMD_LIGHT=" & set "C_OPT=" & set "C_ARG=" & set "C_VALUE="
set "C_TEXT=" & set "C_SECONDARY=" & set "C_TEXT_DIM="
set "C_ERR=" & set "C_WARN=" & set "C_SUCCESS=" & set "C_INFO=" & set "C_HINT="
set "C_EX_EXE=" & set "C_EX_CMD=" & set "C_EX_ARG=" & set "C_EX_VAL=" & set "C_EX_OPT="
set "COLOR_OK="
if defined WT_SESSION set "COLOR_OK=1"
if /I "%ConEmuANSI%"=="ON" set "COLOR_OK=1"
if defined ANSICON set "COLOR_OK=1"
if not defined COLOR_OK reg query "HKCU\Console" /v VirtualTerminalLevel 2>nul | find "0x1" >nul && set "COLOR_OK=1"
if defined NO_COLOR set "COLOR_OK="
if not defined COLOR_OK goto :ColorsDone
REM Capture the raw ESC (0x1B) character via the prompt $E token.
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
set "C_RESET=%ESC%[0m"
set "C_TITLE=%ESC%[38;2;179;190;255m"
set "C_SECTION=%ESC%[38;2;59;120;255m"
set "C_EXE=%ESC%[38;2;170;180;190m"
set "C_CMD=%ESC%[38;2;58;150;221m"
set "C_CMD_LIGHT=%ESC%[38;2;249;241;165m"
set "C_OPT=%ESC%[38;2;19;161;14m"
set "C_ARG=%ESC%[38;2;193;156;0m"
set "C_VALUE=%ESC%[38;2;26;188;156m"
set "C_TEXT=%ESC%[38;2;204;204;204m"
set "C_SECONDARY=%ESC%[38;2;170;180;190m"
set "C_TEXT_DIM=%ESC%[38;2;90;98;112m"
set "C_ERR=%ESC%[38;2;231;76;60m"
set "C_WARN=%ESC%[38;2;241;196;15m"
set "C_SUCCESS=%ESC%[38;2;46;204;113m"
set "C_INFO=%ESC%[38;2;52;152;219m"
set "C_HINT=%ESC%[38;2;98;114;164m"
set "C_EX_EXE=%ESC%[38;2;170;180;190m"
set "C_EX_CMD=%ESC%[38;2;58;150;221m"
set "C_EX_ARG=%ESC%[38;2;26;188;156m"
set "C_EX_VAL=%ESC%[38;2;98;114;164m"
set "C_EX_OPT=%ESC%[38;2;46,204,113m"
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
echo   %C_HINT%%EDGE_REPO%\install\usb\config\rescue\user-data.template%C_RESET%
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
echo.
echo %C_TITLE%LISA Edge CLI (Windows Day-0 Provisioning)%C_RESET%
echo.
echo %C_SECTION%Usage:%C_RESET%
echo   %C_EXE%lisa-edge %C_CMD%^<command^> %C_ARG%[arguments...]%C_RESET%
echo.
echo %C_SECTION%Commands:%C_RESET%
echo   %C_CMD%usb list%C_RESET%                                  %C_TEXT%List available USB disks %C_SECONDARY%^(number, drive letter, label, size^) %C_TEXT%to identify the target.%C_RESET%
echo   %C_CMD%usb build %C_ARG%production %C_HINT%[disk-number]        %C_TEXT%Download Ubuntu, create a bootable USB, and inject the production profile.%C_RESET%
echo   %C_CMD%usb build %C_ARG%rescue %C_HINT%[disk-number]            %C_TEXT%Download Ubuntu, create a bootable USB, and inject the rescue profile.%C_RESET%
echo   %C_CMD%usb prepare %C_ARG%production%C_RESET% %C_ARG%[options] %C_HINT%[drive]  %C_TEXT%Inject the production profile into an existing Ubuntu USB.%C_RESET%
echo   %C_CMD%usb prepare %C_ARG%rescue%C_RESET% %C_HINT%^<drive^>                %C_TEXT%Inject the rescue profile into an existing Ubuntu USB.%C_RESET%
echo   %C_CMD%config%C_RESET% %C_ARG%[production]                       %C_TEXT%Generate or validate the production autoinstall configuration %C_SECONDARY%^(no USB required^)%C_RESET%
echo   %C_CMD%help%C_RESET%                                      %C_TEXT%Show this help message.%C_RESET%
echo.
echo %C_SECTION%Options: %C_TEXT_DIM%(usb prepare production)%C_RESET%
echo   %C_OPT%-a%C_TEXT%, %C_CMD%--auto-detect%C_RESET%                         %C_TEXT%Automatically detect the Ubuntu bootable USB.%C_RESET%
echo   %C_OPT%-y%C_TEXT%, %C_CMD%--yes%C_RESET%                                 %C_TEXT%Skip confirmation prompts.%C_RESET%
echo   %C_CMD%--dry-run%C_RESET%                                 %C_TEXT%Preview the actions without making any changes.%C_RESET%
echo   %C_CMD%--config-only%C_RESET%                             %C_TEXT%Validate the configuration only.%C_RESET%
echo.
echo %C_SECTION%Examples:%C_RESET%
echo   %C_EX_EXE%lisa-edge %C_EX_CMD%usb list%C_RESET%
echo   %C_EX_EXE%lisa-edge %C_EX_CMD%usb build %C_EX_ARG%production%C_RESET%
echo   %C_EX_EXE%lisa-edge %C_EX_CMD%usb build %C_EX_ARG%production %C_EX_ARG%2 %C_EX_ARG%--dry-run%C_RESET%
echo   %C_EX_EXE%lisa-edge %C_EX_CMD%usb prepare %C_EX_ARG%production %C_EX_ARG%--auto-detect%C_RESET%
echo   %C_EX_EXE%lisa-edge %C_EX_CMD%usb prepare %C_EX_ARG%rescue %C_EX_ARG%E:%C_RESET%
echo   %C_EX_EXE%lisa-edge %C_EX_CMD%config%C_RESET%
echo.
echo Runtime operations (setup, bootstrap, deploy, backup, restore, ...)
echo are performed on the Linux host via %C_CMD_LIGHT%./lisa-edge%C_RESET%
echo.
exit /b 0
