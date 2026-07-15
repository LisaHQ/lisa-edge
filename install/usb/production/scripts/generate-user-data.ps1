Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$templatePath = $env:LISA_TEMPLATE
$outputPath = $env:LISA_OUT
$sshPublicKey = $env:LISA_SSH_PUBLIC_KEY
$diskMatchKey = $env:LISA_DISK_MATCH_KEY
$diskMatchValue = $env:LISA_DISK_MATCH_VALUE
$gitRef = $env:LISA_GIT_REF

if ([string]::IsNullOrWhiteSpace($templatePath) -or -not (Test-Path -LiteralPath $templatePath)) {
    throw "Template file not found: $templatePath"
}

if ([string]::IsNullOrWhiteSpace($outputPath)) {
    throw "Output path is required."
}

if ([string]::IsNullOrWhiteSpace($sshPublicKey)) {
    throw "SSH public key is required."
}

if ($sshPublicKey -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-|sk-ssh-|sk-ecdsa-)') {
    throw "SSH public key does not look like a supported OpenSSH public key."
}

if ($diskMatchKey -notin @("serial", "model", "size")) {
    throw "Unsupported disk match key: $diskMatchKey"
}

if ([string]::IsNullOrWhiteSpace($diskMatchValue)) {
    throw "Disk match value is required."
}

if ([string]::IsNullOrWhiteSpace($gitRef)) {
    $gitRef = "main"
}

if ($gitRef -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -or $gitRef -match '\.\.') {
    throw "Git ref contains unsupported characters: $gitRef"
}

function ConvertTo-YamlSingleQuoted {
    param([Parameter(Mandatory = $true)][string]$Value)
    return "'" + ($Value -replace "'", "''") + "'"
}

$content = [System.IO.File]::ReadAllText($templatePath)

$sshPattern = '(?m)^(\s*)-\s*ssh-ed25519\s+REPLACE_WITH_YOUR_PUBLIC_KEY\s+lisa-edge-admin\s*$'
if ([regex]::Matches($content, $sshPattern).Count -ne 1) {
    throw "Expected exactly one SSH public key placeholder in template."
}

$content = [regex]::Replace(
    $content,
    $sshPattern,
    {
        param($match)
        return "{0}- {1}" -f $match.Groups[1].Value, $sshPublicKey.Trim()
    }
)

$gitRefPlaceholder = 'REPLACE_WITH_LISA_EDGE_GIT_REF'
if ([regex]::Matches($content, $gitRefPlaceholder).Count -ne 1) {
    throw "Expected exactly one LISA Edge Git ref placeholder in template."
}
$content = $content.Replace($gitRefPlaceholder, $gitRef.Trim())

$diskPattern = '(?m)^(\s*)serial:\s*REPLACE_WITH_TARGET_DISK_SERIAL\s*$'
if ([regex]::Matches($content, $diskPattern).Count -ne 1) {
    throw "Expected exactly one disk serial placeholder in template."
}

$content = [regex]::Replace(
    $content,
    $diskPattern,
    {
        param($match)
        $indent = $match.Groups[1].Value
        if ($diskMatchKey -eq "size") {
            return "${indent}size: largest"
        }

        $quotedValue = ConvertTo-YamlSingleQuoted -Value $diskMatchValue.Trim()
        return "{0}{1}: {2}" -f $indent, $diskMatchKey, $quotedValue
    }
)

$remainingPlaceholders = [regex]::Matches($content, 'REPLACE_WITH_|YOUR_|CHANGEME')
if ($remainingPlaceholders.Count -gt 0) {
    throw "Generated user-data still contains placeholder values."
}

$outputDir = Split-Path -Parent $outputPath
if (-not [string]::IsNullOrWhiteSpace($outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outputPath, $content, $utf8NoBom)
