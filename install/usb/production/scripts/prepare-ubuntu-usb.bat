@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM LISA Edge - Ubuntu USB Preparation Tool
REM ============================================================
REM Purpose:
REM   Prepare an Ubuntu Server USB installer for unattended
REM   LISA Edge Production deployment.
REM
REM Behavior:
REM   - Detects the Ubuntu USB installer automatically when possible.
REM   - Validates required autoinstall files.
REM   - Refuses to use user-data when common placeholders remain.
REM   - Validates USB write access before modifying files.
REM   - Backs up existing target files before replacing them.
REM   - Verifies copied files after installation.
REM   - Can generate user-data from user-data.template interactively.
REM   - Supports dry-run, config-only, and non-interactive execution.
REM
REM Usage:
REM   prepare-ubuntu-usb.bat [OPTIONS] [USB_DRIVE]
REM
REM Options:
REM   --dry-run       Validate and display actions without modifying USB.
REM   --config-only   Validate source configuration only. No USB required.
REM   --yes           Skip confirmation prompt.
REM   -y              Same as --yes.
REM   --help          Show this help message.
REM   -h              Same as --help.
REM
REM Examples:
REM   prepare-ubuntu-usb.bat --auto-detect
REM   prepare-ubuntu-usb.bat E:
REM   prepare-ubuntu-usb.bat --dry-run
REM   prepare-ubuntu-usb.bat --dry-run E:
REM   prepare-ubuntu-usb.bat --config-only
REM   prepare-ubuntu-usb.bat --yes E:
REM
REM Expected project layout:
REM   production\
REM   ├── autoinstall\
REM   └── scripts\
REM       └── prepare-ubuntu-usb.bat
REM ============================================================

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%\.." >nul 2>nul
set "PROJECT_ROOT=%CD%"
popd >nul 2>nul

set "AUTOINSTALL_DIR=%PROJECT_ROOT%\autoinstall"
set "STEP_TOTAL=9"
set "STEP_COL=75"

set "ESC="
set "CLR_RESET=%ESC%[0m"
set "CLR_RED_DARK=%ESC%[31m"
set "CLR_GREEN_DARK=%ESC%[32m"
set "CLR_YELLOW_DARK=%ESC%[33m"
set "CLR_BLUE_DARK=%ESC%[34m"
set "CLR_VIOLET_DARK=%ESC%[35m"
set "CLR_CYAN_DARK=%ESC%[36m"
set "CLR_WHITE_DARK=%ESC%[37m"
set "CLR_GRAY=%ESC%[90m"
set "CLR_RED=%ESC%[91m"
set "CLR_GREEN=%ESC%[92m"
set "CLR_YELLOW=%ESC%[93m"
set "CLR_BLUE=%ESC%[94m"
set "CLR_VIOLET=%ESC%[95m"
set "CLR_CYAN=%ESC%[96m"
set "CLR_WHITE=%ESC%[97m"

rem echo %CLR_RED_DARK%"CLR_RED_DARK=[31m"%CLR_RESET%
rem echo %CLR_GREEN_DARK%"CLR_GREEN_DARK=[32m"%CLR_RESET%
rem echo %CLR_YELLOW_DARK%"CLR_YELLOW_DARK=[33m"%CLR_RESET%
rem echo %CLR_BLUE_DARK%"CLR_BLUE_DARK=[34m"%CLR_RESET%
rem echo %CLR_VIOLET_DARK%"CLR_VIOLET_DARK=[35m"%CLR_RESET%
rem echo %CLR_CYAN_DARK%"CLR_CYAN_DARK=[36m"%CLR_RESET%
rem echo %CLR_WHITE_DARK%"CLR_WHITE_DARK=[37m"%CLR_RESET%
rem echo %CLR_GRAY%"CLR_GRAY=[90m"%CLR_RESET%
rem echo %CLR_RED%"CLR_RED=[91m"%CLR_RESET%
rem echo %CLR_GREEN%"CLR_GREEN=[92m"%CLR_RESET%
rem echo %CLR_YELLOW%"CLR_YELLOW=[93m"%CLR_RESET%
rem echo %CLR_BLUE%"CLR_BLUE=[94m"%CLR_RESET%
rem echo %CLR_VIOLET%"CLR_VIOLET=[95m"%CLR_RESET%
rem echo %CLR_CYAN%"CLR_CYAN=[96m"%CLR_RESET%
rem echo %CLR_WHITE%"CLR_WHITE=[97m"%CLR_RESET%

set "AUTO_DETECT=0"
set "ASSUME_YES=0"
set "CONFIG_ONLY=0"
set "DRY_RUN=0"
set "DRY_RUN_OR_CONFIG_ONLY=0"

set "USB_DRIVE="
set "USB_CANDIDATE_COUNT=0"
set "BACKUP_TS="
set "EXISTING_TARGET_FILES=0"
set "BACKUP_FILE_USER_DATA="
set "BACKUP_FILE_META_DATA="
set "BACKUP_FILE_GRUB_CFG="

set "USER_DATA_SOURCE="
set "META_DATA_SOURCE="
set "GRUB_CFG_SOURCE="


REM ============================================================
REM MAIN
REM ============================================================

call :ParseArgs %*
if errorlevel 1 exit /b 1

call :Banner

call :DetectUsbDrive
if errorlevel 1 exit /b 1

call :ValidateUsbDrive
if errorlevel 1 exit /b 1

call :ValidateSourceFiles
if errorlevel 1 exit /b 1

call :GenerateTimestamp
if errorlevel 1 exit /b 1

call :CheckExistingFiles
if errorlevel 1 exit /b 1

call :PrintPlan

call :Confirm
if errorlevel 1 exit /b 1

call :ValidateWriteAccess
if errorlevel 1 exit /b 1

call :PrepareTargets
if errorlevel 1 exit /b 1

call :BackupExistingFiles
if errorlevel 1 exit /b 1

call :CopyFiles
if errorlevel 1 exit /b 1

call :VerifyCopy
if errorlevel 1 exit /b 1

call :Finish
exit /b


REM ============================================================
REM HELPERS
REM ============================================================

:Info
set "INFO_MSG=%*"
echo %INFO_MSG%
exit /b

:Error
set "ERROR_MSG=%*"
echo %CLR_RED%ERROR: %ERROR_MSG%%CLR_RESET%
exit /b

:BeginStep
set "CURRENT_STEP_NO=%~1"
set "CURRENT_STEP_MSG=%~2"
set "STEP=%CLR_WHITE%%CURRENT_STEP_NO%/%STEP_TOTAL%%CLR_RESET%"
set "LINE=[%CLR_CYAN_DARK%....%CLR_RESET%] [%STEP%] %CURRENT_STEP_MSG%"
<nul set /p =%LINE%
powershell -nop -c "Start-Sleep -m 200"
exit /b

:StepDone
call :PrintStatus "DONE"
exit /b

:StepPass
call :PrintStatus "PASS"
exit /b

:StepFail
call :PrintStatus "FAIL"
exit /b

:StepSkip
call :PrintStatus "SKIP"
exit /b

:StepSimulate
call :PrintStatus "SIM "
exit /b

:PrintStatus
set "STATUS=%~1"
if /i "%STATUS%"=="DONE" (
    set "COLOR=%CLR_GREEN_DARK%"
) else if /i "%STATUS%"=="PASS" (
    set "COLOR=%CLR_GREEN%"
) else if /i "%STATUS%"=="SKIP" (
    set "COLOR=%CLR_YELLOW_DARK%"
) else if /i "%STATUS%"=="SIM " (
    set "COLOR=%CLR_CYAN_DARK%"
) else if /i "%STATUS%"=="FAIL" (
    set "COLOR=%CLR_RED_DARK%"
) else (
    set "COLOR=%CLR_RESET%"
)
rem Clear line, reset cursor and print the latest line.
<nul set /p "=%ESC%[2K%ESC%[G"
set "LINE=[%COLOR%%STATUS%%CLR_RESET%] [%STEP%] %CURRENT_STEP_MSG%"
echo %LINE%
exit /b

REM ------------------------------------------------------------
REM ParseArgs()
REM ------------------------------------------------------------
:ParseArgs
if "%~1"=="" (
    call :Usage
    exit /b 1
)

:ParseArgsLoop
rem if "%~1"=="" exit /b 0

if "%~1"=="" (
    if "%DRY_RUN_OR_CONFIG_ONLY%"=="0" (
        if "%AUTO_DETECT%"=="0" (
            if "%USB_DRIVE%"=="" (
                rem if "%ASSUME_YES%"=="0" exit /b 1
                if "%ASSUME_YES%"=="1" (
                    call :Error '--yes' and '-y' option cannot standalone.
                    call :Usage
                )
                exit /b 1
            )
        )
    )
    exit /b 0
)


if /I "%~1"=="--auto-detect" (
    set "AUTO_DETECT=1"
    shift
    goto :ParseArgsLoop
)

if /I "%~1"=="-a" (
    set "AUTO_DETECT=1"
    shift
    goto :ParseArgsLoop
)

if /I "%~1"=="--yes" (
    set "ASSUME_YES=1"
    shift
    goto :ParseArgsLoop
)

if /I "%~1"=="-y" (
    set "ASSUME_YES=1"
    shift
    goto :ParseArgsLoop
)

if /I "%~1"=="--help" (
    call :Usage
    exit /b 1
)

if /I "%~1"=="-h" (
    call :Usage
    exit /b 1
)

if /I "%~1"=="--dry-run" (
    set "DRY_RUN=1"
    set "DRY_RUN_OR_CONFIG_ONLY=1"
    shift
    goto :ParseArgsLoop
)

if /I "%~1"=="--config-only" (
    set "CONFIG_ONLY=1"
    set "DRY_RUN_OR_CONFIG_ONLY=1"
    shift
    goto :ParseArgsLoop
)

set "ARG=%~1"
if "%ARG:~0,1%"=="-" (
    call :Error Unknown option: %~1
    call :Usage
    exit /b 1
)

if not "%USB_DRIVE%"=="" (
    call :Error Only one USB drive may be provided.
    call :Usage
    exit /b 1
)

set "USB_DRIVE=%~1"
shift
goto :ParseArgsLoop

REM ------------------------------------------------------------
REM Banner()
REM ------------------------------------------------------------
:Banner
echo.
echo =================================================================
echo.
echo            %CLR_YELLOW%LISA Edge - Ubuntu USB Preparation Tool%CLR_RESET%
echo.
echo =================================================================
echo.
exit /b 0

REM ------------------------------------------------------------
REM Usage()
REM ------------------------------------------------------------
:Usage
echo.
echo %CLR_WHITE%Usage:%CLR_RESET%
echo   %CLR_YELLOW%prepare-ubuntu-usb.bat %CLR_CYAN%[%CLR_GRAY%OPTIONS%CLR_CYAN%] [%CLR_BLUE%USB_DRIVE%CLR_CYAN%]%CLR_RESET%
echo.
echo %CLR_WHITE%Options:%CLR_RESET%
echo   %CLR_GRAY%--auto-detect   %CLR_RESET%Auto detect the USB drive and install files to it.
echo   %CLR_GRAY%-a              %CLR_RESET%Same as %CLR_GRAY%--auto-detect%CLR_RESET%.
echo   %CLR_GRAY%--yes           %CLR_RESET%Skip confirmation prompt. Should be used with %CLR_GRAY%--auto-detect%CLR_RESET%, or %CLR_GRAY%-a%CLR_RESET%, or %CLR_BLUE%USB_DRIVE%CLR_RESET%.
echo   %CLR_GRAY%-y              %CLR_RESET%Same as %CLR_GRAY%--yes%CLR_RESET%.
echo   %CLR_GRAY%--dry-run       %CLR_RESET%Validate and display actions without modifying USB.
echo   %CLR_GRAY%--config-only   %CLR_RESET%Validate or generate source configuration only. No USB required.
echo   %CLR_GRAY%--help          %CLR_RESET%Show this help message.
echo   %CLR_GRAY%-h              %CLR_RESET%Same as %CLR_GRAY%--help%CLR_RESET%.
echo.
echo %CLR_WHITE%Examples:%CLR_RESET%
echo   %CLR_YELLOW%prepare-ubuntu-usb.bat%CLR_GRAY% --auto-detect %CLR_RESET%
echo   %CLR_YELLOW%prepare-ubuntu-usb.bat%CLR_GRAY% -a %CLR_RESET%
echo   %CLR_YELLOW%prepare-ubuntu-usb.bat%CLR_GRAY% %CLR_BLUE%E: %CLR_RESET%
echo   %CLR_YELLOW%prepare-ubuntu-usb.bat%CLR_GRAY% --yes %CLR_BLUE%E: %CLR_RESET%
echo   %CLR_YELLOW%prepare-ubuntu-usb.bat%CLR_GRAY% -y %CLR_BLUE%E: %CLR_RESET%
echo   %CLR_YELLOW%prepare-ubuntu-usb.bat%CLR_GRAY% --dry-run %CLR_RESET%
echo   %CLR_YELLOW%prepare-ubuntu-usb.bat%CLR_GRAY% --dry-run %CLR_BLUE%E: %CLR_RESET%
echo   %CLR_YELLOW%prepare-ubuntu-usb.bat%CLR_GRAY% --config-only %CLR_RESET%
echo.
exit /b 0

REM ------------------------------------------------------------
REM DetectUsbDrive()
REM ------------------------------------------------------------
:DetectUsbDrive
if not "%USB_DRIVE%"=="" exit /b 0
call :BeginStep 1 "Searching file-system drives for Ubuntu USB installer"

if "%CONFIG_ONLY%"=="1" (
    call :StepSkip
    exit /b 0
)

set "USB_CANDIDATE_COUNT=0"

for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Get-PSDrive -PSProvider FileSystem | ForEach-Object { $root=$_.Root; if ((Test-Path ($root + 'casper')) -and (Test-Path ($root + 'boot\grub'))) { $root.TrimEnd('\') } }"`) do (
    set "CAND=%%D"
    if exist "!CAND!\casper" (
        if exist "!CAND!\boot\grub" (
            set /a USB_CANDIDATE_COUNT+=1
            set "USB_CANDIDATE_!USB_CANDIDATE_COUNT!=!CAND!"
            set "USB_DRIVE=!CAND!"
        )
    )
)

if "%USB_CANDIDATE_COUNT%"=="0" (
    call :StepFail
    call :Error Could not auto-detect the Ubuntu USB installer.
    call :Usage
    exit /b 1
)

if not "%USB_CANDIDATE_COUNT%"=="1" (
    call :StepFail
    call :Error Multiple Ubuntu USB installers detected. Specify the USB drive explicitly.
    echo Candidates:
    for /L %%I in (1,1,%USB_CANDIDATE_COUNT%) do echo   !USB_CANDIDATE_%%I!
    exit /b 1
)

call :StepDone
exit /b 0

REM ------------------------------------------------------------
REM ValidateUsbDrive()
REM ------------------------------------------------------------
:ValidateUsbDrive
call :BeginStep 2 "Validating USB media %CLR_BLUE%%USB_DRIVE%%CLR_RESET%"

if "%CONFIG_ONLY%"=="1" (
    call :StepSkip
    exit /b 0
)

if not exist "%USB_DRIVE%\" (
    call :StepFail
    call :Error Drive does not exist:
    echo   %USB_DRIVE%
    exit /b 1
)

if not exist "%USB_DRIVE%\casper" (
    call :StepFail
    call :Error This does not look like an Ubuntu installer USB.
    echo Missing directory:
    echo   %USB_DRIVE%\casper
    exit /b 1
)

if not exist "%USB_DRIVE%\boot\grub" (
    call :StepFail
    call :Error GRUB directory not found on USB.
    echo Missing directory:
    echo   %USB_DRIVE%\boot\grub
    exit /b 1
)

call :StepPass
exit /b 0

REM ------------------------------------------------------------
REM ValidateSourceFiles()
REM ------------------------------------------------------------
:ValidateSourceFiles
call :BeginStep 3 "Validating source files"

set "USER_DATA_SOURCE="

if exist "%AUTOINSTALL_DIR%\user-data" (
    set "USER_DATA_SOURCE=%AUTOINSTALL_DIR%\user-data"
)

if "%USER_DATA_SOURCE%"=="" (
    if exist "%AUTOINSTALL_DIR%\user-data.template" (
        call :StepSkip
        call :GenerateUserDataFromTemplate
        if errorlevel 1 exit /b 1
        call :BeginStep 3 "Validating generated user-data"
        set "USER_DATA_SOURCE=%AUTOINSTALL_DIR%\user-data"
    ) else (
        call :StepFail
        call :Error Missing user-data:
        echo   %AUTOINSTALL_DIR%
        exit /b 1
    )
)

findstr /C:"REPLACE_WITH_" /C:"YOUR_" /C:"CHANGEME" "%USER_DATA_SOURCE%" >nul 2>nul
if "%ERRORLEVEL%"=="0" (
    call :StepFail
    call :Error user-data still contains placeholder values.
    echo.
    echo File:
    echo   %USER_DATA_SOURCE%
    echo.
    echo Check values such as:
    echo   - SSD serial
    echo   - SSH public key
    echo   - Hostname
    exit /b 1
)

set "META_DATA_SOURCE=%AUTOINSTALL_DIR%\meta-data"
if not exist "%META_DATA_SOURCE%" (
    call :StepFail
    call :Error Missing meta-data:
    echo   %META_DATA_SOURCE%
    exit /b 1
)

set "GRUB_CFG_SOURCE=%AUTOINSTALL_DIR%\grub.cfg"
if not exist "%GRUB_CFG_SOURCE%" (
    call :StepFail
    call :Error Missing grub.cfg:
    echo   %GRUB_CFG_SOURCE%
    exit /b 1
)

call :StepPass
exit /b 0

REM ------------------------------------------------------------
REM GenerateUserDataFromTemplate()
REM ------------------------------------------------------------
:GenerateUserDataFromTemplate
if "%DRY_RUN%"=="1" (
    call :Error Missing deployable user-data. Dry-run will not generate files.
    echo.
    echo Run without %CLR_GRAY%--dry-run%CLR_RESET% to launch the config wizard, or create:
    echo   %AUTOINSTALL_DIR%\user-data
    exit /b 1
)

if "%ASSUME_YES%"=="1" (
    call :Error Missing deployable user-data. The config wizard needs interactive input.
    echo.
    echo Create this file before using %CLR_GRAY%--yes%CLR_RESET%:
    echo   %AUTOINSTALL_DIR%\user-data
    exit /b 1
)

echo.
echo ------------------------------------------------------------
echo %CLR_YELLOW%Config Wizard%CLR_RESET%
echo ------------------------------------------------------------
echo.
echo No deployable user-data was found.
echo This wizard will create:
echo   %CLR_CYAN%%AUTOINSTALL_DIR%\user-data%CLR_RESET%
echo.
echo Template:
echo   %CLR_CYAN_DARK%%AUTOINSTALL_DIR%\user-data.template%CLR_RESET%
echo.

call :PromptSshPublicKey
if errorlevel 1 exit /b 1

call :PromptDiskMatch
if errorlevel 1 exit /b 1

call :PromptGitRef
if errorlevel 1 exit /b 1

set "LISA_TEMPLATE=%AUTOINSTALL_DIR%\user-data.template"
set "LISA_OUT=%AUTOINSTALL_DIR%\user-data"
set "LISA_SSH_PUBLIC_KEY=%SSH_PUBLIC_KEY%"
set "LISA_DISK_MATCH_KEY=%DISK_MATCH_KEY%"
set "LISA_DISK_MATCH_VALUE=%DISK_MATCH_VALUE%"
set "LISA_GIT_REF=%GIT_REF%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%generate-user-data.ps1"
if errorlevel 1 (
    call :Error Could not generate user-data from template.
    exit /b 1
)

echo.
echo Created:
echo   %CLR_CYAN%%AUTOINSTALL_DIR%\user-data%CLR_RESET%
echo.
exit /b 0

REM ------------------------------------------------------------
REM PromptGitRef()
REM ------------------------------------------------------------
:PromptGitRef
echo.
echo LISA Edge release:
echo   Use a release tag for reproducible production installs.
echo   Use main only for development or when following the current branch is intended.
echo.
set "GIT_REF="
set /p GIT_REF=Git branch or release tag [main]:
if "%GIT_REF%"=="" set "GIT_REF=main"
echo %GIT_REF% | findstr /R /C:"^[A-Za-z0-9][A-Za-z0-9._/-]*$" >nul 2>nul
if errorlevel 1 (
    call :Error Git ref contains unsupported characters.
    exit /b 1
)
echo %GIT_REF% | findstr /C:".." >nul 2>nul
if not errorlevel 1 (
    call :Error Git ref cannot contain two consecutive dots.
    exit /b 1
)
exit /b 0

REM ------------------------------------------------------------
REM PromptSshPublicKey()
REM ------------------------------------------------------------
:PromptSshPublicKey
set "SSH_PUBLIC_KEY="
set "DEFAULT_SSH_PUBLIC_KEY="

if exist "%USERPROFILE%\.ssh\id_ed25519.pub" (
    set /p DEFAULT_SSH_PUBLIC_KEY=<"%USERPROFILE%\.ssh\id_ed25519.pub"
)

if not "!DEFAULT_SSH_PUBLIC_KEY!"=="" (
    echo SSH public key:
    echo   Found local key:
    echo   !DEFAULT_SSH_PUBLIC_KEY!
    echo.
    set "USE_DEFAULT_SSH_KEY="
    set /p USE_DEFAULT_SSH_KEY=Use this key? [Y/n]: 
    if /I "!USE_DEFAULT_SSH_KEY!"=="" set "SSH_PUBLIC_KEY=!DEFAULT_SSH_PUBLIC_KEY!"
    if /I "!USE_DEFAULT_SSH_KEY!"=="Y" set "SSH_PUBLIC_KEY=!DEFAULT_SSH_PUBLIC_KEY!"
    if /I "!USE_DEFAULT_SSH_KEY!"=="YES" set "SSH_PUBLIC_KEY=!DEFAULT_SSH_PUBLIC_KEY!"
)

if "!SSH_PUBLIC_KEY!"=="" (
    echo SSH public key:
    echo   Paste the full public key, for example:
    echo   ssh-ed25519 AAAAC3... lisa-edge-admin
    echo.
    echo   If you do not have one yet, create it first:
    echo   ssh-keygen -t ed25519 -C lisa-edge-admin
    echo.
    set /p SSH_PUBLIC_KEY=Public key: 
)

if "!SSH_PUBLIC_KEY!"=="" (
    call :Error SSH public key is required.
    exit /b 1
)

echo !SSH_PUBLIC_KEY! | findstr /R /C:"^ssh-ed25519 " /C:"^ssh-rsa " /C:"^ecdsa-sha2-" /C:"^sk-ssh-" /C:"^sk-ecdsa-" >nul 2>nul
if errorlevel 1 (
    call :Error SSH public key should start with ssh-ed25519, ssh-rsa, ecdsa-sha2-, sk-ssh-, or sk-ecdsa-.
    exit /b 1
)

exit /b 0

REM ------------------------------------------------------------
REM PromptDiskMatch()
REM ------------------------------------------------------------
:PromptDiskMatch
set "DISK_MATCH_KEY="
set "DISK_MATCH_VALUE="

:PromptDiskMatchMenu
echo.
echo Target disk selection:
echo   %CLR_WHITE%1%CLR_RESET% - Disk serial number %CLR_GREEN_DARK%(recommended)%CLR_RESET%
echo   %CLR_WHITE%2%CLR_RESET% - Largest disk %CLR_YELLOW_DARK%(fallback; only safe on single-disk targets)%CLR_RESET%
echo   %CLR_WHITE%3%CLR_RESET% - Disk model name %CLR_YELLOW_DARK%(less specific than serial)%CLR_RESET%
echo   %CLR_WHITE%4%CLR_RESET% - Show commands to find disk serial and stop
echo.
set "DISK_MATCH_CHOICE="
set /p DISK_MATCH_CHOICE=Choose [1]: 
if "%DISK_MATCH_CHOICE%"=="" set "DISK_MATCH_CHOICE=1"

if "%DISK_MATCH_CHOICE%"=="1" goto :PromptDiskSerial
if "%DISK_MATCH_CHOICE%"=="2" goto :PromptDiskLargest
if "%DISK_MATCH_CHOICE%"=="3" goto :PromptDiskModel
if "%DISK_MATCH_CHOICE%"=="4" goto :PrintDiskDiscoveryHelp

call :Error Invalid disk selection.
goto :PromptDiskMatchMenu

:PromptDiskSerial
echo.
echo On the target machine, disk serial can be found with:
echo   Linux:   lsblk -o NAME,MODEL,SERIAL,SIZE
echo   Windows: Get-CimInstance Win32_DiskDrive ^| Select Model,SerialNumber,Size
echo.
set "DISK_SERIAL="
set /p DISK_SERIAL=Target disk serial: 
if "%DISK_SERIAL%"=="" (
    call :Error Disk serial is required for this option.
    goto :PromptDiskMatchMenu
)
set "DISK_MATCH_KEY=serial"
set "DISK_MATCH_VALUE=%DISK_SERIAL%"
exit /b 0

:PromptDiskLargest
echo.
echo %CLR_YELLOW_DARK%WARNING:%CLR_RESET% This will install to the largest matching disk.
echo Use this only when the target hardware has one intended install disk.
echo.
set "CONFIRM_LARGEST="
set /p CONFIRM_LARGEST=Type LARGEST to continue: 
if /I not "%CONFIRM_LARGEST%"=="LARGEST" (
    echo Aborted largest-disk selection.
    goto :PromptDiskMatchMenu
)
set "DISK_MATCH_KEY=size"
set "DISK_MATCH_VALUE=largest"
exit /b 0

:PromptDiskModel
echo.
echo Model matching is useful when serial is unavailable, but it can match multiple disks.
set "DISK_MODEL="
set /p DISK_MODEL=Target disk model: 
if "%DISK_MODEL%"=="" (
    call :Error Disk model is required for this option.
    goto :PromptDiskMatchMenu
)
set "DISK_MATCH_KEY=model"
set "DISK_MATCH_VALUE=%DISK_MODEL%"
exit /b 0

:PrintDiskDiscoveryHelp
echo.
echo To find the target disk serial:
echo   Linux installer shell:
echo     lsblk -o NAME,MODEL,SERIAL,SIZE
echo.
echo   Windows PowerShell on the target:
echo     Get-CimInstance Win32_DiskDrive ^| Select Model,SerialNumber,Size
echo.
echo Re-run this script when you have the value.
exit /b 1

REM ------------------------------------------------------------
REM GenerateTimestamp()
REM ------------------------------------------------------------
:GenerateTimestamp
for /f %%I in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd-HHmmss')" 2^>nul') do (
    set "BACKUP_TS=%%I"
)
if "%BACKUP_TS%"=="" (
    call :Error Could not generate backup timestamp.
    exit /b 1
)
exit /b 0

REM ------------------------------------------------------------
REM CheckExistingFiles()
REM ------------------------------------------------------------
:CheckExistingFiles
call :BeginStep 4 "Check existing files to backup"
if "%CONFIG_ONLY%"=="1" (
    call :StepSkip
    exit /b 0
)
if exist "%USB_DRIVE%\autoinstall\user-data" (
    set "BACKUP_FILE_USER_DATA=%USB_DRIVE%\backups\%BACKUP_TS%\autoinstall\user-data"
    set "EXISTING_TARGET_FILES=1"
)
if exist "%USB_DRIVE%\autoinstall\meta-data" (
    set "BACKUP_FILE_META_DATA=%USB_DRIVE%\backups\%BACKUP_TS%\autoinstall\meta-data"
    set "EXISTING_TARGET_FILES=1"
)
if exist "%USB_DRIVE%\boot\grub\grub.cfg" (
    set "BACKUP_FILE_GRUB_CFG=%USB_DRIVE%\backups\%BACKUP_TS%\boot\grub\grub.cfg"
    set "EXISTING_TARGET_FILES=1"
)
call :StepDone
exit /b 0

REM ------------------------------------------------------------
REM PrintPlan()
REM ------------------------------------------------------------
:PrintPlan
if "%EXISTING_TARGET_FILES%"=="0"  exit /b 0
if "%DRY_RUN_OR_CONFIG_ONLY%"=="1"  exit /b 0
if "%ASSUME_YES%"=="1"  exit /b 0
echo.
echo ------------------------------------------------------------
echo %CLR_YELLOW%Plan Summary%CLR_RESET%
echo ------------------------------------------------------------
echo.
echo   Mode:
echo     %CLR_VIOLET%APPLY%CLR_RESET% - USB files may be backed up and replaced.
echo.
echo   Source files:
echo     %CLR_CYAN_DARK%%USER_DATA_SOURCE%%CLR_RESET%
echo     %CLR_CYAN_DARK%%META_DATA_SOURCE%%CLR_RESET%
echo     %CLR_CYAN_DARK%%GRUB_CFG_SOURCE%%CLR_RESET%
echo.
echo   Target USB:
echo     %CLR_BLUE%%USB_DRIVE%%CLR_RESET%
echo.
echo   Destination files will be copied to:
echo     %CLR_CYAN%%USB_DRIVE%\autoinstall\%CLR_CYAN_DARK%user-data%CLR_RESET%
echo     %CLR_CYAN%%USB_DRIVE%\autoinstall\%CLR_CYAN_DARK%meta-data%CLR_RESET%
echo     %CLR_CYAN%%USB_DRIVE%\boot\grub\%CLR_CYAN_DARK%grub.cfg%CLR_RESET%
echo.
echo   Existing target files will be backed up to:
if not "%BACKUP_FILE_USER_DATA%"=="" echo     %CLR_YELLOW_DARK%%BACKUP_FILE_USER_DATA%%CLR_RESET%
if not "%BACKUP_FILE_META_DATA%"=="" echo     %CLR_YELLOW_DARK%%BACKUP_FILE_META_DATA%%CLR_RESET%
if not "%BACKUP_FILE_GRUB_CFG%"=="" echo     %CLR_YELLOW_DARK%%BACKUP_FILE_GRUB_CFG%%CLR_RESET%
echo.
echo ------------------------------------------------------------
echo.
exit /b 0

REM ------------------------------------------------------------
REM Confirm()
REM ------------------------------------------------------------
:Confirm
if "%EXISTING_TARGET_FILES%"=="0"  exit /b 0
if "%DRY_RUN_OR_CONFIG_ONLY%"=="1"  exit /b 0
if "%ASSUME_YES%"=="1"  exit /b 0
set "CONFIRM="
set /p CONFIRM=Type YES to continue:
if /I not "%CONFIRM%"=="YES" (
    echo %CLR_YELLOW_DARK%Aborted.%CLR_RESET%
    exit /b 1
)
exit /b 0

REM ------------------------------------------------------------
REM ValidateWriteAccess()
REM ------------------------------------------------------------
:ValidateWriteAccess
call :BeginStep 5 "Validating USB write access"

if "%CONFIG_ONLY%"=="1" (
    call :StepSkip
    exit /b 0
)

if "%DRY_RUN%"=="1" (
    call :StepSkip
    exit /b 0
)

set "WRITE_TEST_FILE=%USB_DRIVE%\.lisa-edge-write-test.%RANDOM%%RANDOM%"

> "%WRITE_TEST_FILE%" echo test
if errorlevel 1 (
    call :StepFail
    call :Error USB is not writable:
    echo   %USB_DRIVE%
    exit /b 1
)

del /f /q "%WRITE_TEST_FILE%" >nul 2>nul

call :StepPass
exit /b 0

REM ------------------------------------------------------------
REM PrepareTargets()
REM ------------------------------------------------------------
:PrepareTargets
call :BeginStep 6 "Preparing target directories"

if "%CONFIG_ONLY%"=="1" (
    call :StepSkip
    exit /b 0
)

if "%DRY_RUN%"=="1" (
    call :StepSimulate
    call :Info Would create:
    echo   %USB_DRIVE%\autoinstall\
    echo   %USB_DRIVE%\backups\%BACKUP_TS%\autoinstall\
    echo   %USB_DRIVE%\backups\%BACKUP_TS%\boot\grub\
    exit /b 0
)

call :EnsureDir "%USB_DRIVE%\autoinstall"
if errorlevel 1 exit /b 1

call :EnsureDir "%USB_DRIVE%\backups\%BACKUP_TS%\autoinstall"
if errorlevel 1 exit /b 1

call :EnsureDir "%USB_DRIVE%\backups\%BACKUP_TS%\boot\grub"
if errorlevel 1 exit /b 1

call :StepDone
exit /b 0

REM ------------------------------------------------------------
REM EnsureDir()
REM ------------------------------------------------------------
:EnsureDir
set "TARGET_DIR=%~1"
if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%" 2>nul
    if errorlevel 1 (
        call :Error Could not create directory:
        echo   %TARGET_DIR%
        exit /b 1
    )
)
exit /b 0

REM ------------------------------------------------------------
REM BackupExistingFiles()
REM ------------------------------------------------------------
:BackupExistingFiles
call :BeginStep 7 "Backing up existing files"

if "%CONFIG_ONLY%"=="1" (
    call :StepSkip
    exit /b 0
)

if "%DRY_RUN%"=="1" (
    call :StepSimulate
)

if not "%BACKUP_FILE_USER_DATA%"=="" (
    call :BackupFile "%USB_DRIVE%\autoinstall\user-data" "%BACKUP_FILE_USER_DATA%"
rem    if errorlevel 1 exit /b 1
    if errorlevel 1 (
        call :StepFail
        call :Error Could not back up file:
        echo   "%USB_DRIVE%\autoinstall\user-data"
        exit /b 1
    )
)

if not "%BACKUP_FILE_META_DATA%"=="" (
    call :BackupFile "%USB_DRIVE%\autoinstall\meta-data" "%BACKUP_FILE_META_DATA%"
rem    if errorlevel 1 exit /b 1
    if errorlevel 1 (
        call :StepFail
        call :Error Could not back up file:
        echo   "%USB_DRIVE%\autoinstall\meta-data"
        exit /b 1
    )
)

if not "%BACKUP_FILE_GRUB_CFG%"=="" (
    call :BackupFile "%USB_DRIVE%\boot\grub\grub.cfg" "%BACKUP_FILE_GRUB_CFG%"
rem    if errorlevel 1 exit /b 1
    if errorlevel 1 (
        call :StepFail
        call :Error Could not back up file:
        echo   "%USB_DRIVE%\boot\grub\grub.cfg"
        exit /b 1
    )
)

if "%DRY_RUN%"=="0" (
    call :StepDone
)

exit /b 0

REM ------------------------------------------------------------
REM BackupFile()
REM ------------------------------------------------------------
:BackupFile
set "TARGET_FILE=%~1"
set "BACKUP_FILE=%~2"
if exist "%TARGET_FILE%" (
    if "%DRY_RUN_OR_CONFIG_ONLY%"=="1" (
        call :Info Would back up:
        echo   %TARGET_FILE%
        echo   -^> %BACKUP_FILE%
    ) else (
        move /Y "%TARGET_FILE%" "%BACKUP_FILE%" >nul
        if errorlevel 1 (
            exit /b 1
        )
    )
) else (
    call :Info No existing file to back up:
    echo   %TARGET_FILE%
)
exit /b 0

REM ------------------------------------------------------------
REM CopyFiles()
REM ------------------------------------------------------------
:CopyFiles
call :BeginStep 8 "Installing autoinstall configuration"

if "%CONFIG_ONLY%"=="1" (
    call :StepSkip
    exit /b 0
)

if "%DRY_RUN%"=="1" (
    call :StepSimulate
    call :Info Would copy:
    echo   %USER_DATA_SOURCE%
    echo   -^> %USB_DRIVE%\autoinstall\user-data
    echo   %META_DATA_SOURCE%
    echo   -^> %USB_DRIVE%\autoinstall\meta-data
    echo   %GRUB_CFG_SOURCE%
    echo   -^> %USB_DRIVE%\boot\grub\grub.cfg
    exit /b 0
)

copy /Y "%USER_DATA_SOURCE%" "%USB_DRIVE%\autoinstall\user-data" >nul
if errorlevel 1 (
    call :Error Could not copy user-data.
    exit /b 1
)

copy /Y "%META_DATA_SOURCE%" "%USB_DRIVE%\autoinstall\meta-data" >nul
if errorlevel 1 (
    call :Error Could not copy meta-data.
    exit /b 1
)

copy /Y "%GRUB_CFG_SOURCE%" "%USB_DRIVE%\boot\grub\grub.cfg" >nul
if errorlevel 1 (
    call :Error Could not copy grub.cfg.
    exit /b 1
)

call :StepDone
exit /b 0

REM ------------------------------------------------------------
REM VerifyCopy()
REM ------------------------------------------------------------
:VerifyCopy
call :BeginStep 9 "Verifying installed files"

if "%DRY_RUN_OR_CONFIG_ONLY%"=="1" (
    call :StepSkip
    exit /b 0
)

call :VerifyFile "%USER_DATA_SOURCE%" "%USB_DRIVE%\autoinstall\user-data"
if errorlevel 1 (
    call :StepFail
    call :Error Verification failed:
    echo   Source: "%USER_DATA_SOURCE%"
    echo   Target: "%USB_DRIVE%\autoinstall\user-data"
    exit /b 1
)

call :VerifyFile "%META_DATA_SOURCE%" "%USB_DRIVE%\autoinstall\meta-data"
if errorlevel 1 (
    call :StepFail
    call :Error Verification failed:
    echo   Source: "%META_DATA_SOURCE%"
    echo   Target: "%USB_DRIVE%\autoinstall\meta-data"
    exit /b 1
)

call :VerifyFile "%GRUB_CFG_SOURCE%" "%USB_DRIVE%\boot\grub\grub.cfg"
if errorlevel 1 (
    call :StepFail
    call :Error Verification failed:
    echo   Source: "%GRUB_CFG_SOURCE%"
    echo   Target: "%USB_DRIVE%\boot\grub\grub.cfg"
    exit /b 1
)

call :StepPass
exit /b 0

REM ------------------------------------------------------------
REM VerifyFile()
REM ------------------------------------------------------------
:VerifyFile
set "SOURCE_FILE=%~1"
set "TARGET_FILE=%~2"
fc /b "%SOURCE_FILE%" "%TARGET_FILE%" >nul
if errorlevel 1 exit /b 1
exit /b 0

REM ------------------------------------------------------------
REM PrintRollbackCommands()
REM ------------------------------------------------------------
:PrintRollbackCommands
echo Rollback commands:
if not "%BACKUP_FILE_USER_DATA%"=="" (
    echo   %CLR_YELLOW%copy %CLR_GRAY%/Y %CLR_CYAN_DARK%%BACKUP_FILE_USER_DATA% %USB_DRIVE%\autoinstall\user-data%CLR_RESET%
)
if not "%BACKUP_FILE_META_DATA%"=="" (
    echo   %CLR_YELLOW%copy %CLR_GRAY%/Y %CLR_CYAN_DARK%%BACKUP_FILE_META_DATA% %USB_DRIVE%\autoinstall\meta-data%CLR_RESET%
)
if not "%BACKUP_FILE_GRUB_CFG%"=="" (
    echo   %CLR_YELLOW%copy %CLR_GRAY%/Y %CLR_CYAN_DARK%%BACKUP_FILE_GRUB_CFG% %USB_DRIVE%\boot\grub\grub.cfg%CLR_RESET%
)
exit /b 0

REM ------------------------------------------------------------
REM Finish()
REM ------------------------------------------------------------
:Finish
echo.
echo =================================================================
if "%CONFIG_ONLY%"=="1" (
    echo    %CLR_YELLOW%CONFIG ONLY - Checking Complete%CLR_RESET%
) else if "%DRY_RUN%"=="1" (
    echo    %CLR_YELLOW%Dry Run Complete%CLR_RESET%
) else (
    echo    %CLR_YELLOW%Installation Complete%CLR_RESET%
)
echo -----------------------------------------------------------------
echo.
if "%CONFIG_ONLY%"=="0" (
    echo Target USB Drive:
    echo   %CLR_BLUE%%USB_DRIVE%%CLR_RESET%
    echo.
    echo Backup files:
    if not "%BACKUP_FILE_USER_DATA%"=="" echo   %CLR_YELLOW_DARK%%BACKUP_FILE_USER_DATA%%CLR_RESET%
    if not "%BACKUP_FILE_META_DATA%"=="" echo   %CLR_YELLOW_DARK%%BACKUP_FILE_META_DATA%%CLR_RESET%
    if not "%BACKUP_FILE_GRUB_CFG%"=="" echo   %CLR_YELLOW_DARK%%BACKUP_FILE_GRUB_CFG%%CLR_RESET%
    echo.
)
echo Installation files:
if "%CONFIG_ONLY%"=="1" (
    echo   %CLR_CYAN%%USER_DATA_SOURCE%%CLR_RESET%
    echo   %CLR_CYAN%%META_DATA_SOURCE%%CLR_RESET%
    echo   %CLR_CYAN%%GRUB_CFG_SOURCE%%CLR_RESET%
) else (
    echo   %CLR_CYAN%%USB_DRIVE%\autoinstall\user-data%CLR_RESET%
    echo   %CLR_CYAN%%USB_DRIVE%\autoinstall\meta-data%CLR_RESET%
    echo   %CLR_CYAN%%USB_DRIVE%\boot\grub\grub.cfg%CLR_RESET%
)
echo.
if "%DRY_RUN_OR_CONFIG_ONLY%"=="0" (
    call :PrintRollbackCommands
    echo.
    echo Next Steps:%CLR_WHITE%
    echo   1. Safely eject the USB.
    echo   2. Insert into target hardware.
    echo   3. Boot from USB.
    echo   4. Verify autoinstall starts automatically.
    echo.%CLR_RESET%
)
echo =================================================================
exit /b 0
