<#
.SYNOPSIS
  Builds (if needed) and runs the map editor CLI to generate a Red Alert skirmish map.

.DESCRIPTION
  B4 defaults (126×8 reference-style):
    -Players 8          eight waypoints (max generator supports)
    -MapSize / -Size 126   required for octagonOpen / middleRoad reference cells
    -SpawnLayout octagonOpen   (or use -Recipe octagon8)

  Recipe aliases (-Recipe):
    octagon8      -> octagonOpen  (Octagon Open V1.4 survey cells)
    middle-road   -> middleRoad   (Middle Road 2-6p survey cells)
    corners8      -> corners8     (procedural corner + edge midpoints)

  Quality gate: .mpr >= 10 KB and .tga >= 4 KB (truncated 4096-byte .mpr fails).

.EXAMPLE
  .\Generate-RAMap.ps1 -Recipe octagon8 -Name AIGen_8p_Large02 -Seed 20260704 -Build

.EXAMPLE
  .\Generate-RAMap.ps1 -Recipe middle-road -Name AIGen_MiddleRoad01 -Players 8
#>
param(
    [string] $Name = "AIGen_Test",
    [int] $Seed = 42,
    [int] $Players = 8,
    [Alias("MapSize")]
    [int] $Size = 126,
    [string] $SpawnLayout = "",
    [ValidateSet("octagon8", "middle-road", "corners8", "octagonOpen", "middleRoad", "")]
    [string] $Recipe = "octagon8",
    [double] $OreDensity = 0.72,
    [double] $GemDensity = 0.06,
    [int] $Mines = 16,
    [int] $OrePatches = 18,
    [string] $Theater = "Temperate",
    [string] $DataPath = "C:\Program Files (x86)\Steam\steamapps\common\CnCRemastered",
    [string] $OutPath = "",
    [switch] $Build
)

$ErrorActionPreference = "Stop"

$recipeToLayout = @{
    "octagon8"     = "octagonOpen"
    "octagonOpen"  = "octagonOpen"
    "middle-road"  = "middleRoad"
    "middleRoad"   = "middleRoad"
    "corners8"     = "corners8"
}

if ($SpawnLayout) {
    $layoutKey = $SpawnLayout
} elseif ($Recipe) {
    $layoutKey = $Recipe
} else {
    $layoutKey = "octagon8"
}

if (-not $recipeToLayout.ContainsKey($layoutKey)) {
    throw "Unknown recipe/layout '$layoutKey'. Use -Recipe octagon8|middle-road|corners8 or -SpawnLayout octagonOpen|middleRoad|corners8."
}
$SpawnLayout = $recipeToLayout[$layoutKey]

if ($SpawnLayout -in @("octagonOpen", "middleRoad") -and $Size -ne 126) {
    Write-Warning "Spawn layout '$SpawnLayout' uses 126×126 reference cells; forcing -Size 126."
    $Size = 126
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$subRoot = Join-Path $repoRoot "Source\Rampastring-MoreQoL"
$sln = Join-Path $subRoot "CnCTDRAMapEditor.sln"
$editorExe = Join-Path $subRoot "CnCTDRAMapEditor\bin\Debug\CnCTDRAMapEditorD.exe"

if ($Build -or -not (Test-Path $editorExe)) {
    Write-Host "Building CnCTDRAMapEditor (Debug)..."
    $msbuild = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
    if (-not $msbuild) {
        throw "MSBuild not found. Install Visual Studio Build Tools or build CnCTDRAMapEditor.sln manually."
    }
    & $msbuild $sln /p:Configuration=Debug /p:Platform="Any CPU" /restore /v:m
    if ($LASTEXITCODE -ne 0) {
        throw "Map editor build failed."
    }
}

if (-not (Test-Path $editorExe)) {
    throw "Editor not found: $editorExe"
}

# Do not pass --data on the command line: Start-Process splits unquoted paths at spaces.
# WorkingDirectory is set to $DataPath; MapGenCli default root matches Steam install.
$cliArgs = @(
    "--mapgen", "generate",
    "--name", $Name,
    "--seed", $Seed,
    "--players", $Players,
    "--size", $Size,
    "--spawn-layout", $SpawnLayout,
    "--ore", $OreDensity,
    "--gems", $GemDensity,
    "--mines", $Mines,
    "--ore-patches", $OrePatches,
    "--theater", $Theater
)

if ($OutPath) {
    $cliArgs += @("--out", $OutPath)
}

Write-Host "Recipe=$layoutKey -> spawn-layout=$SpawnLayout, size=$Size, players=$Players, seed=$Seed"
Write-Host "Running map generator (may take 10-30 seconds for preview)..."
$proc = Start-Process `
    -FilePath $editorExe `
    -ArgumentList $cliArgs `
    -WorkingDirectory $DataPath `
    -Wait -PassThru -NoNewWindow
$exitCode = $proc.ExitCode
if ($exitCode -ne 0) {
    $log = Join-Path (Split-Path $editorExe -Parent) "mapgen.log"
    if (Test-Path $log) {
        Get-Content $log -Tail 12 | Write-Host
    }
    throw "Map generation exited with code $exitCode. See mapgen.log beside the editor EXE."
}

$minMprBytes = 10000
$minTgaBytes = 4096
$outName = if ($OutPath) { [System.IO.Path]::GetFileNameWithoutExtension($OutPath) } else { $Name }
$outDir = Join-Path $env:USERPROFILE "Documents\CnCRemastered\Local_Custom_Maps\Red_Alert"
$outMpr = Join-Path $outDir "$outName.mpr"
$outTga = Join-Path $outDir "$outName.tga"
$outJson = Join-Path $outDir "$outName.json"

if (-not (Test-Path $outMpr)) {
    throw "Expected output not found: $outMpr"
}

$len = (Get-Item $outMpr).Length
$tgaLen = if (Test-Path $outTga) { (Get-Item $outTga).Length } else { 0 }
$jsonLen = if (Test-Path $outJson) { (Get-Item $outJson).Length } else { 0 }
Write-Host "Output triplet: $outName.mpr ($len bytes), .tga ($tgaLen bytes), .json ($jsonLen bytes)"

if ($len -lt $minMprBytes -or $tgaLen -lt $minTgaBytes) {
    throw "Map output below B4 quality gate (mpr=$len need >=$minMprBytes, tga=$tgaLen need >=$minTgaBytes). Check mapgen.log."
}
if (-not (Test-Path $outJson)) {
    throw "Missing sidecar: $outJson"
}

Write-Host "Done. Triplet ready under Local_Custom_Maps\Red_Alert\ (unless --out was set)."