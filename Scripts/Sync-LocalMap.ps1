<#
.SYNOPSIS
  Copies a generated map triplet (.mpr, .tga, .json) into Local_Custom_Maps\Red_Alert.

.DESCRIPTION
  Verifies all three files exist in SourceDir, enforces B4 quality gate (.mpr >= 10 KB,
  .tga >= 4 KB), then copies with matching basename into the remaster local maps folder.
#>
param(
    [Parameter(Mandatory = $true)]
    [string] $SourceDir,

    [Parameter(Mandatory = $true)]
    [string] $BaseName,

    [int] $MinMprBytes = 10000,
    [int] $MinTgaBytes = 4096,
    [switch] $Launch
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $SourceDir)) {
    throw "SourceDir not found: $SourceDir"
}

$destRoot = Join-Path $env:USERPROFILE "Documents\CnCRemastered\Local_Custom_Maps\Red_Alert"
if (-not (Test-Path $destRoot)) {
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
}

$extensions = @(".mpr", ".tga", ".json")
$sizes = @{}
foreach ($ext in $extensions) {
    $src = Join-Path $SourceDir ($BaseName + $ext)
    if (-not (Test-Path $src)) {
        throw "Missing required triplet file: $src"
    }
    $sizes[$ext] = (Get-Item $src).Length
}

if ($sizes[".mpr"] -lt $MinMprBytes) {
    throw "Source .mpr too small ($($sizes['.mpr']) bytes < $MinMprBytes). Regenerate with Generate-RAMap.ps1."
}
if ($sizes[".tga"] -lt $MinTgaBytes) {
    throw "Source .tga too small ($($sizes['.tga']) bytes < $MinTgaBytes). Run Repair-RAMapPreviews.ps1 or regenerate."
}
if ($sizes[".json"] -le 0) {
    throw "Source .json is empty: $(Join-Path $SourceDir ($BaseName + '.json'))"
}

Write-Host "Triplet verified: .mpr=$($sizes['.mpr']), .tga=$($sizes['.tga']), .json=$($sizes['.json']) bytes"

foreach ($ext in $extensions) {
    $src = Join-Path $SourceDir ($BaseName + $ext)
    $dst = Join-Path $destRoot ($BaseName + $ext)
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "Copied -> $dst"
}

Write-Host "Map '$BaseName' triplet is ready under Local_Custom_Maps\Red_Alert."

if ($Launch) {
    $launcher = Join-Path $PSScriptRoot "..\Launchers\Launch-Aeloria-Stable.bat"
    if (Test-Path $launcher) {
        Write-Host "Launching: $launcher"
        Start-Process -FilePath $launcher -WorkingDirectory (Split-Path $launcher -Parent)
    } else {
        Write-Warning "Launcher not found: $launcher"
    }
}