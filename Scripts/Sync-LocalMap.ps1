# Copies a generated map triplet (.mpr, .tga, .json) into Local_Custom_Maps\Red_Alert.
param(
    [Parameter(Mandatory = $true)]
    [string] $SourceDir,

    [Parameter(Mandatory = $true)]
    [string] $BaseName,

    [switch] $Launch
)

$ErrorActionPreference = "Stop"

$destRoot = Join-Path $env:USERPROFILE "Documents\CnCRemastered\Local_Custom_Maps\Red_Alert"
if (-not (Test-Path $destRoot)) {
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
}

$extensions = @(".mpr", ".tga", ".json")
foreach ($ext in $extensions) {
    $src = Join-Path $SourceDir ($BaseName + $ext)
    if (-not (Test-Path $src)) {
        throw "Missing required file: $src"
    }
    $dst = Join-Path $destRoot ($BaseName + $ext)
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "Copied -> $dst"
}

Write-Host "Map '$BaseName' is ready under Local_Custom_Maps\Red_Alert."

if ($Launch) {
    $launcher = Join-Path $PSScriptRoot "..\Launchers\Launch-Aeloria-Stable.bat"
    if (Test-Path $launcher) {
        Write-Host "Launching: $launcher"
        Start-Process -FilePath $launcher -WorkingDirectory (Split-Path $launcher -Parent)
    } else {
        Write-Warning "Launcher not found: $launcher"
    }
}