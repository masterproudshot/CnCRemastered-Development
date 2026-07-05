# Builds (if needed) and runs the map editor CLI to generate a Red Alert skirmish map.
param(
    [string] $Name = "AIGen_Test",
    [int] $Seed = 42,
    [int] $Players = 4,
    [int] $Size = 64,
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
    "--ore", $OreDensity,
    "--gems", $GemDensity,
    "--mines", $Mines,
    "--ore-patches", $OrePatches,
    "--theater", $Theater
)

if ($OutPath) {
    $cliArgs += @("--out", $OutPath)
}

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

$outName = if ($OutPath) { [System.IO.Path]::GetFileNameWithoutExtension($OutPath) } else { $Name }
$outMpr = Join-Path $env:USERPROFILE "Documents\CnCRemastered\Local_Custom_Maps\Red_Alert\$outName.mpr"
if (Test-Path $outMpr) {
    $len = (Get-Item $outMpr).Length
    $tga = Join-Path (Split-Path $outMpr) "$outName.tga"
    $tgaLen = if (Test-Path $tga) { (Get-Item $tga).Length } else { 0 }
    Write-Host "Output: $outName.mpr ($len bytes), .tga ($tgaLen bytes)"
    if ($len -le 5000 -or $tgaLen -lt 4096) {
        throw "Map output looks truncated (mpr=$len, tga=$tgaLen). Check mapgen.log."
    }
}
else {
    throw "Expected output not found: $outMpr"
}

Write-Host "Done. Check Documents\CnCRemastered\Local_Custom_Maps\Red_Alert\ for output (unless --out was set)."