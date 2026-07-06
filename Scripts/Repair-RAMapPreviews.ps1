# Regenerates .tga + .json sidecars for Red Alert custom maps (fixes missing minimap previews).
param(
    [string] $MapDir = "",
    [string] $DataPath = "C:\Program Files (x86)\Steam\steamapps\common\CnCRemastered",
    [string] $NamePrefix = "",
    [switch] $Build,
    [switch] $AllowPartialFailure
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$editorExe = Join-Path $repoRoot "Source\Rampastring-MoreQoL\CnCTDRAMapEditor\bin\Debug\CnCTDRAMapEditorD.exe"
$sln = Join-Path $repoRoot "Source\Rampastring-MoreQoL\CnCTDRAMapEditor.sln"

if ($Build -or -not (Test-Path $editorExe)) {
    $msbuild = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
    if (-not $msbuild) { throw "MSBuild not found." }
    & $msbuild $sln /p:Configuration=Debug /p:Platform="Any CPU" /restore /v:m
}

if (-not $MapDir) {
    $MapDir = Join-Path $env:USERPROFILE "Documents\CnCRemastered\Local_Custom_Maps\Red_Alert"
}

$mprFiles = Get-ChildItem -Path $MapDir -Filter "*.mpr" -File
if ($NamePrefix) {
    $mprFiles = $mprFiles | Where-Object { $_.BaseName -like "${NamePrefix}*" }
}
if ($mprFiles.Count -eq 0) {
    throw "No .mpr files found in $MapDir (prefix='$NamePrefix')."
}

$ok = 0
$fail = 0
Push-Location $DataPath
try {
    foreach ($mpr in $mprFiles) {
        $cliArgs = @(
            "--mapgen", "repair-previews",
            "--mpr", $mpr.FullName
        )
        $proc = Start-Process -FilePath $editorExe -ArgumentList $cliArgs -WorkingDirectory $DataPath -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0) {
            $ok++
            Write-Host "OK $($mpr.Name)" -ForegroundColor Green
        }
        else {
            $fail++
            Write-Warning "FAIL $($mpr.Name) (truncated or invalid MPR - regenerate map)"
        }
    }
}
finally {
    Pop-Location
}

Write-Host "Done. $ok repaired, $fail failed - $MapDir" -ForegroundColor Cyan
if ($fail -gt 0 -and -not $AllowPartialFailure) {
    throw "$fail map(s) could not be repaired."
}