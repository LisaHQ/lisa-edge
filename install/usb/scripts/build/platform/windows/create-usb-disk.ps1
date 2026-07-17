# Create a bootable Ubuntu installer USB from a verified ISO (replaces Rufus).
#
# Windows counterpart of platform/linux/create-usb-disk.sh.
# Approach (UEFI-only, same as Rufus "ISO mode"):
#   GPT + one FAT32 partition + full ISO contents copied onto it.
# The USB stays writable so the autoinstall prepare scripts can inject
# user-data / meta-data / grub.cfg afterwards.
#
# DESTRUCTIVE: erases the selected disk. Validation is fail-closed:
#   - the target must report BusType 'USB' (never a SATA/NVMe/system disk)
#   - boot and system disks are rejected
#   - the disk number is never guessed; -DiskNumber is mandatory
#   - confirmation requires typing ERASE <n> unless -Force
#
# Prints the USB drive letter (e.g. "E:") as the LAST stdout line.
# Run "create-usb-disk.ps1 -List" to list candidate USB disks.

[CmdletBinding()]
param(
    [int]$DiskNumber = -1,
    [string]$IsoPath = "",
    [string]$Label = "LISA-USB",
    [switch]$Force,
    [switch]$DryRun,
    [switch]$List
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Fat32MaxPartBytes = 32GB - 64MB   # Windows cannot format FAT32 volumes above 32 GB
$Fat32MaxFileBytes = 4GB - 1
$MinDiskBytes      = 4GB

if ($List) {
    Write-Host ""
    Write-Host "USB disks visible to Windows:"
    $columns = @(
        'Number', 'FriendlyName', 'SerialNumber',
        @{ Label = 'Size(GB)'; Expression = { [math]::Round($_.Size / 1GB, 1) } },
        'IsBoot', 'IsSystem'
    )
    Get-Disk | Where-Object { $_.BusType -eq 'USB' } |
        Format-Table -AutoSize -Property $columns | Out-Host
    Write-Host "Pass the disk number via -DiskNumber. Only BusType USB disks are accepted."
    exit 0
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must run from an elevated (Administrator) prompt."
}

if ($DiskNumber -lt 0) {
    throw "-DiskNumber is required (never guessed). Run with -List to see candidate USB disks."
}
if ([string]::IsNullOrWhiteSpace($IsoPath)) {
    throw "-IsoPath is required (see fetch-ubuntu-iso.ps1)."
}
if (-not (Test-Path -LiteralPath $IsoPath)) {
    throw "ISO not found: $IsoPath"
}
$IsoPath = (Resolve-Path -LiteralPath $IsoPath).Path
$isoBytes = (Get-Item -LiteralPath $IsoPath).Length

# --- fail-closed disk validation ---------------------------------------------
$disk = Get-Disk -Number $DiskNumber
if ($disk.BusType -ne 'USB') {
    throw "Disk $DiskNumber ($($disk.FriendlyName)) has BusType '$($disk.BusType)', not USB. Refusing to erase it (fail closed)."
}
if ($disk.IsBoot -or $disk.IsSystem) {
    throw "Disk $DiskNumber is a boot/system disk. Refusing to erase it."
}
if ($disk.Size -lt $MinDiskBytes) {
    throw "Disk $DiskNumber is smaller than 4 GB; too small for an Ubuntu installer."
}
if ($disk.Size -lt ($isoBytes + 256MB)) {
    throw "Disk $DiskNumber ($($disk.Size) bytes) is too small for the ISO ($isoBytes bytes)."
}

# --- inspect the ISO before touching the disk ---------------------------------
Write-Host "Mounting ISO to inspect its contents..."
$image = Mount-DiskImage -ImagePath $IsoPath -Access ReadOnly -PassThru
try {
    $isoVolume = $image | Get-Volume
    if ($null -eq $isoVolume -or [string]::IsNullOrWhiteSpace([string]$isoVolume.DriveLetter)) {
        throw "Windows did not assign a drive letter to the mounted ISO."
    }
    $isoRoot = "$($isoVolume.DriveLetter):\"

    if (-not (Test-Path -LiteralPath (Join-Path $isoRoot "casper"))) {
        throw "ISO does not look like an Ubuntu live installer (missing casper\)."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $isoRoot "EFI\boot\bootx64.efi"))) {
        throw "ISO has no UEFI bootloader (EFI\boot\bootx64.efi); this pipeline is UEFI-only."
    }
    $oversized = Get-ChildItem -LiteralPath $isoRoot -Recurse -File |
        Where-Object { $_.Length -gt $Fat32MaxFileBytes } | Select-Object -First 1
    if ($oversized) {
        throw "ISO contains a file larger than 4 GiB, which FAT32 cannot store: $($oversized.FullName)"
    }

    if ($DryRun) {
        $partBytes = [math]::Min($disk.Size - 16MB, $Fat32MaxPartBytes)
        Write-Host "[dry-run] validation passed for disk $DiskNumber ($($disk.FriendlyName))"
        Write-Host "[dry-run] would create: GPT + FAT32 partition ($([math]::Round($partBytes / 1GB, 1)) GB, label $Label)"
        Write-Host "[dry-run] would copy ISO contents from $IsoPath"
        Write-Host "[dry-run] no changes were made"
        exit 0
    }

    # --- confirmation ----------------------------------------------------------
    Write-Host ""
    Write-Host "About to ERASE ALL DATA on:"
    Write-Host ("  Disk {0}: {1}  {2} GB  Serial: {3}" -f $disk.Number, $disk.FriendlyName,
        [math]::Round($disk.Size / 1GB, 1), $disk.SerialNumber)
    Write-Host ""
    if (-not $Force) {
        $answer = Read-Host "Type ERASE $DiskNumber to continue"
        if ($answer -ne "ERASE $DiskNumber") {
            throw "Confirmation did not match; aborting with no changes."
        }
    } else {
        Write-Host "-Force given; skipping confirmation."
    }

    # --- partition + format ----------------------------------------------------
    Write-Host "Erasing disk $DiskNumber..."
    if ($disk.PartitionStyle -ne 'RAW') {
        Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false
    }
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT

    Write-Host "Creating FAT32 partition..."
    if ($disk.Size -le $Fat32MaxPartBytes) {
        $partition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter
    } else {
        $partition = New-Partition -DiskNumber $DiskNumber -Size $Fat32MaxPartBytes -AssignDriveLetter
    }
    $null = Format-Volume -Partition $partition -FileSystem FAT32 -NewFileSystemLabel $Label -Confirm:$false
    $partition = Get-Partition -DiskNumber $DiskNumber | Where-Object { $_.Type -ne 'Reserved' } | Select-Object -First 1
    if ($null -eq $partition -or [string]::IsNullOrWhiteSpace([string]$partition.DriveLetter)) {
        throw "Windows did not assign a drive letter to the new USB partition."
    }
    $usbLetter = "$($partition.DriveLetter):"

    # --- copy installer files ---------------------------------------------------
    Write-Host "Copying installer files to $usbLetter (this can take a few minutes)..."
    $robocopyArgs = @("$($isoVolume.DriveLetter):\.", "$usbLetter\.", "/E", "/R:2", "/W:2", "/XJ", "/NFL", "/NDL", "/NJH", "/NJS")
    & robocopy @robocopyArgs | Out-Host
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy reported a copy failure (exit code $LASTEXITCODE)."
    }
    $global:LASTEXITCODE = 0

    # --- verify anchors -----------------------------------------------------------
    foreach ($anchor in @("casper", "EFI\boot\bootx64.efi", "boot\grub\grub.cfg")) {
        if (-not (Test-Path -LiteralPath (Join-Path "$usbLetter\" $anchor))) {
            throw "Copy verification failed: $anchor missing on $usbLetter"
        }
    }

    Write-Host "Bootable Ubuntu USB ready (UEFI) at $usbLetter"
    Write-Output $usbLetter
} finally {
    Dismount-DiskImage -ImagePath $IsoPath | Out-Null
}
exit 0
