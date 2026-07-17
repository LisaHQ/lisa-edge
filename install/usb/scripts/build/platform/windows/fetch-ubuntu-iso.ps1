# Download and verify the Ubuntu Server ISO defined in config/ubuntu-releases.json.
#
# Windows counterpart of platform/linux/fetch-ubuntu-iso.sh.
# Prints the absolute path of the verified ISO as the LAST stdout line;
# progress goes to the console (Write-Host) so callers can capture the path:
#   for /f "usebackq delims=" %%I in (`powershell ... -File fetch-ubuntu-iso.ps1`) do set "ISO=%%I"

[CmdletBinding()]
param(
    [string]$Release = "",
    [string]$ConfigPath = "",
    [string]$CacheDir = "",
    [switch]$Offline
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    # Script lives in install/usb/scripts/build/platform/windows -> config is 4 levels up.
    $ConfigPath = Join-Path $PSScriptRoot "..\..\..\..\config\ubuntu-releases.json"
}
if ([string]::IsNullOrWhiteSpace($CacheDir)) {
    $CacheDir = Join-Path $env:LOCALAPPDATA "lisa-edge\iso"
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Release config not found: $ConfigPath"
}
$ConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($Release)) {
    $Release = $config.default
}
if ([string]::IsNullOrWhiteSpace($Release)) {
    throw "No release requested and no `"default`" entry in $ConfigPath"
}

$entry = $config.releases.PSObject.Properties[$Release]
if ($null -eq $entry) {
    throw "Release `"$Release`" is not defined in $ConfigPath"
}
$entry = $entry.Value

function Get-EntryValue {
    param($Object, [string]$Name, [string]$Default = "")
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
        return [string]$prop.Value
    }
    return $Default
}

$mirror = Get-EntryValue $entry "mirror"
if ([string]::IsNullOrWhiteSpace($mirror)) { throw "Release `"$Release`" is missing `"mirror`"" }
if ($mirror -notmatch '^https://') { throw "Mirror must use https: $mirror" }
$flavor = Get-EntryValue $entry "flavor" "live-server"
$arch   = Get-EntryValue $entry "arch" "amd64"
$isoPin = Get-EntryValue $entry "iso"
$shaPin = Get-EntryValue $entry "sha256"

New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
$sumsPath = Join-Path $CacheDir "SHA256SUMS.$Release"

if (-not $Offline) {
    Write-Host "Fetching checksum index: $mirror/SHA256SUMS"
    Invoke-WebRequest -Uri "$mirror/SHA256SUMS" -OutFile "$sumsPath.tmp" -UseBasicParsing
    Move-Item -Force "$sumsPath.tmp" $sumsPath
}

function Get-SumsEntries {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    Get-Content -LiteralPath $Path | ForEach-Object {
        if ($_ -match '^([0-9a-fA-F]{64})\s+\*?(\S+)\s*$') {
            [pscustomobject]@{ Hash = $Matches[1].ToLower(); Name = $Matches[2] }
        }
    }
}

$sums = @(Get-SumsEntries -Path $sumsPath)

$isoName = ""
$expectedSha = ""
if (-not [string]::IsNullOrWhiteSpace($isoPin)) {
    $isoName = $isoPin
    if (-not [string]::IsNullOrWhiteSpace($shaPin)) {
        $expectedSha = $shaPin.ToLower()
    } else {
        $match = $sums | Where-Object { $_.Name -eq $isoName } | Select-Object -First 1
        if ($match) { $expectedSha = $match.Hash }
    }
} else {
    $pattern = "^ubuntu-[0-9.]+-$([regex]::Escape($flavor))-$([regex]::Escape($arch))\.iso$"
    $match = $sums | Where-Object { $_.Name -match $pattern } | Select-Object -First 1
    if ($match) {
        $isoName = $match.Name
        $expectedSha = $match.Hash
    }
}

if ([string]::IsNullOrWhiteSpace($isoName)) {
    throw "Could not determine the ISO name for release `"$Release`" ($flavor/$arch). Pin `"iso`" in $ConfigPath or run without -Offline."
}
if ($expectedSha -notmatch '^[0-9a-f]{64}$') {
    throw "No usable SHA256 for $isoName (not in SHA256SUMS and no `"sha256`" pin)."
}

$isoPath = Join-Path $CacheDir $isoName

function Test-IsoHash {
    param([string]$Path, [string]$Expected)
    Write-Host "Verifying: $Path"
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
    return ($actual -eq $Expected)
}

if (Test-Path -LiteralPath $isoPath) {
    if (Test-IsoHash -Path $isoPath -Expected $expectedSha) {
        Write-Host "Checksum OK (cached): $expectedSha"
        Write-Output $isoPath
        exit 0
    }
    Write-Host "Cached ISO failed verification; re-downloading."
    Move-Item -Force $isoPath "$isoPath.corrupt"
}

if ($Offline) {
    throw "-Offline: no verified ISO in cache: $isoPath"
}

$isoUrl = "$mirror/$isoName"
Write-Host "Downloading: $isoUrl"
Write-Host "Destination: $isoPath"
$partPath = "$isoPath.part"
$downloaded = $false
if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
    try {
        Start-BitsTransfer -Source $isoUrl -Destination $partPath -DisplayName "LISA Edge Ubuntu ISO"
        $downloaded = $true
    } catch {
        Write-Host "BITS transfer failed ($($_.Exception.Message)); falling back to direct download."
    }
}
if (-not $downloaded) {
    Invoke-WebRequest -Uri $isoUrl -OutFile $partPath -UseBasicParsing
}

if (-not (Test-IsoHash -Path $partPath -Expected $expectedSha)) {
    Move-Item -Force $partPath "$isoPath.corrupt"
    throw "SHA256 mismatch for $isoName; the corrupt file was set aside. Re-run to retry."
}
Move-Item -Force $partPath $isoPath
Write-Host "Checksum OK: $expectedSha"

Write-Output $isoPath
