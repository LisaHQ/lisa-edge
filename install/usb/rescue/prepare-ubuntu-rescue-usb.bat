@echo off
setlocal EnableExtensions EnableDelayedExpansion

set SCRIPT_DIR=%~dp0
set AUTOINSTALL_DIR=%SCRIPT_DIR%autoinstall

if "%~1"=="" goto usage
if "%~1"=="-h" goto usage
if "%~1"=="--help" goto usage

set USB_DRIVE=%~1

if not exist "%USB_DRIVE%\" (
    echo ERROR: USB drive not found: %USB_DRIVE%
    exit /b 1
)

if not exist "%USB_DRIVE%\casper" (
    echo ERROR: USB does not look like an Ubuntu Server installer.
    echo Missing: %USB_DRIVE%\casper
    exit /b 1
)

if not exist "%AUTOINSTALL_DIR%\meta-data" (
    echo ERROR: Missing %AUTOINSTALL_DIR%\meta-data
    exit /b 1
)

if not exist "%AUTOINSTALL_DIR%\grub.cfg" (
    echo ERROR: Missing %AUTOINSTALL_DIR%\grub.cfg
    exit /b 1
)

set USER_DATA_SOURCE=

if exist "%AUTOINSTALL_DIR%\user-data" (
    set USER_DATA_SOURCE=%AUTOINSTALL_DIR%\user-data
) else (
    if exist "%AUTOINSTALL_DIR%\user-data.template" (
        set USER_DATA_SOURCE=%AUTOINSTALL_DIR%\user-data.template
    )
)

if "%USER_DATA_SOURCE%"=="" (
    echo ERROR: Missing user-data or user-data.template in %AUTOINSTALL_DIR%
    exit /b 1
)

findstr /C:"REPLACE_WITH_" /C:"YOUR_" /C:"CHANGEME" "%USER_DATA_SOURCE%" >nul 2>nul
if %ERRORLEVEL%==0 (
    echo ERROR: rescue user-data still contains placeholder values.
    echo.
    echo Edit one of these files first:
    echo   install\usb\rescue\autoinstall\user-data
    echo   install\usb\rescue\autoinstall\user-data.template
    echo.
    echo Required values usually include:
    echo   - eMMC serial
    echo   - SSH public key
    echo   - password hash
    exit /b 1
)

mkdir "%USB_DRIVE%\autoinstall" >nul 2>nul

copy /Y "%AUTOINSTALL_DIR%\meta-data" "%USB_DRIVE%\autoinstall\meta-data" >nul
copy /Y "%USER_DATA_SOURCE%" "%USB_DRIVE%\autoinstall\user-data" >nul
copy /Y "%AUTOINSTALL_DIR%\grub.cfg" "%USB_DRIVE%\autoinstall\grub.cfg" >nul

if exist "%USB_DRIVE%\boot\grub" (
    if exist "%USB_DRIVE%\boot\grub\grub.cfg" (
        copy /Y "%USB_DRIVE%\boot\grub\grub.cfg" "%USB_DRIVE%\boot\grub\grub.cfg.bak" >nul
    )

    copy /Y "%AUTOINSTALL_DIR%\grub.cfg" "%USB_DRIVE%\boot\grub\grub.cfg" >nul
) else (
    echo WARN: %USB_DRIVE%\boot\grub not found. Autoinstall files were copied, but GRUB was not patched.
)

echo.
echo Rescue USB prepared successfully.
echo.
echo Copied autoinstall files to:
echo   %USB_DRIVE%\autoinstall
echo.
echo Target profile:
echo   LISA Edge Rescue OS on eMMC
exit /b 0

:usage
echo Usage:
echo   install\usb\rescue\prepare-ubuntu-rescue-usb.bat ^<usb-drive^>
echo.
echo Example:
echo   install\usb\rescue\prepare-ubuntu-rescue-usb.bat E:
echo.
echo This script prepares an Ubuntu Server USB for automatic Rescue OS installation.
exit /b 0
