# Generates a batch of 8-player Red Alert skirmish maps (procedural).
param(
    [int] $Count = 8,
    [int] $Size = 64,
    [string] $Theater = "Temperate",
    [int] $BaseSeed = 20260701,
    [string] $NamePrefix = "AIGen_8p"
)

$ErrorActionPreference = "Stop"
$gen = Join-Path $PSScriptRoot "Generate-RAMap.ps1"
if (-not (Test-Path $gen)) {
    throw "Missing $gen"
}

$archive = Join-Path (Split-Path $PSScriptRoot -Parent) "GeneratedMaps"
if (-not (Test-Path $archive)) {
    New-Item -ItemType Directory -Path $archive | Out-Null
}

$made = @()
$built = $false
for ($i = 0; $i -lt $Count; $i++) {
    $seed = $BaseSeed + $i
    $name = "{0}_{1:D2}" -f $NamePrefix, ($i + 1)
    Write-Host "=== $name seed=$seed size=$Size players=8 ===" -ForegroundColor Cyan
    $genArgs = @{
        Name        = $name
        Seed        = $seed
        Players     = 8
        Size        = $Size
        Theater     = $Theater
        Mines       = 16
        OreDensity  = 0.72
        GemDensity  = 0.06
        OrePatches  = 18
    }
    if (-not $built) {
        $genArgs['Build'] = $true
        $built = $true
    }
    & $gen @genArgs
    $src = Join-Path $env:USERPROFILE "Documents\CnCRemastered\Local_Custom_Maps\Red_Alert\$name.mpr"
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $archive "$name.mpr") -Force
        $made += $name
    }
    else {
        Write-Warning "Expected output not found: $src"
    }
}

Write-Host ""
Write-Host "Created $($made.Count) maps in Local_Custom_Maps\Red_Alert and copies in GeneratedMaps:" -ForegroundColor Green
$made | ForEach-Object { Write-Host "  $_" }