@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%..\.."
set "SRC_DIR=%REPO_DIR%\tools\usb\autoinstall"
set "USB_DRIVE="

if not exist "%SRC_DIR%\user-data" (
  echo Missing source file: "%SRC_DIR%\user-data"
  exit /b 1
)
if not exist "%SRC_DIR%\meta-data" (
  echo Missing source file: "%SRC_DIR%\meta-data"
  exit /b 1
)

if not "%~1"=="" (
  set "USB_DRIVE=%~1"
) else (
  echo Searching removable drives for Ubuntu USB...
  for /f "skip=1 tokens=1,2 delims=," %%A in ('wmic logicaldisk where "DriveType=2" get DeviceID^,VolumeName /format:csv 2^>nul') do (
    if not "%%B"=="" (
      set "CAND=%%B"
      set "VOL=%%C"
      if exist "!CAND!\casper" set "USB_DRIVE=!CAND!"
      if exist "!CAND!\boot\grub" set "USB_DRIVE=!CAND!"
    )
  )
)

if "%USB_DRIVE%"=="" (
  echo Could not auto-detect the Ubuntu USB.
  echo Usage: tools\usb\prepare-ubuntu-usb.bat E:
  exit /b 1
)

if not exist "%USB_DRIVE%\" (
  echo Drive does not exist: %USB_DRIVE%
  exit /b 1
)

echo USB drive: %USB_DRIVE%
echo Files will be copied to: %USB_DRIVE%\server
set /p CONFIRM=Type YES to continue: 
if /I not "%CONFIRM%"=="YES" (
  echo Aborted.
  exit /b 1
)

mkdir "%USB_DRIVE%\server" 2>nul
copy /Y "%SRC_DIR%\user-data" "%USB_DRIVE%\server\user-data" >nul
copy /Y "%SRC_DIR%\meta-data" "%USB_DRIVE%\server\meta-data" >nul

echo Copied cloud-init files.
echo.
echo IMPORTANT:
echo Windows batch copied user-data and meta-data, but it does not safely patch grub.cfg.
echo Open the USB grub.cfg and ensure the linux line includes:
echo autoinstall ds=nocloud;s=/cdrom/server/
echo.
echo Done. Eject the USB safely before unplugging it.
exit /b 0
