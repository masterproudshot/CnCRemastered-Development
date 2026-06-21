<#
.SYNOPSIS
    Static crash-coverage audit for Project Aeloria Red Alert DLL guards.

.DESCRIPTION
    Parses DEFINES.H type enums, counts raw Class-> vs Aeloria_Safe_Techno_Type usage
    per techno class CPP, and scores Layer-1/2/3 defense coverage. Emits a markdown
    matrix suitable for Docs/09-Full-Roster-Crash-Coverage-Matrix.md.

.PARAMETER RedAlertDir
    Path to REDALERT source folder (default: bon-5k-5 worktree).

.PARAMETER OutputMarkdown
    Optional path to write the generated matrix markdown.

.EXAMPLE
    .\Scripts\Audit-AeloriaCoverage.ps1 -OutputMarkdown Docs\09-Full-Roster-Crash-Coverage-Matrix.md
#>
[CmdletBinding()]
param(
    [string]$RedAlertDir,
    [string]$OutputMarkdown
)

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$repoRoot = Split-Path $scriptDir -Parent
if (-not $RedAlertDir) {
    $RedAlertDir = Join-Path $repoRoot "worktrees\bon-5k-5\REDALERT"
}

$ErrorActionPreference = "Stop"

if (-not (Test-Path $RedAlertDir)) {
    throw "REDALERT dir not found: $RedAlertDir"
}

$definesPath = Join-Path $RedAlertDir "DEFINES.H"
$defines = Get-Content $definesPath -Raw

function Get-EnumEntries {
    param([string]$EnumName, [string]$StopBefore)
    $pattern = "typedef enum $EnumName[^}]+}"
    if ($defines -notmatch $pattern) { return @() }
    $block = $Matches[0]
    $entries = @()
    foreach ($line in ($block -split "`n")) {
        $t = $line.Trim()
        if ($t -match '^\*/' -or $t -match '^/\*' -or $t -match '^//') { continue }
        if ($t -match '^(#ifdef|#endif|#else)') { continue }
        if ($t -match '^(\w+)\s*=') {
            $entries += $Matches[1]
        } elseif ($t -match '^(\w+)\s*,') {
            $entries += $Matches[1]
        } elseif ($t -match '^(\w+)\s*$' -and $t -notmatch 'enum|typedef') {
            $entries += $Matches[1]
        }
    }
    $filtered = $entries | Where-Object {
        $_ -notmatch '^(NONE|COUNT|FIRST|RA_COUNT)$' -and $_ -notmatch '^STRUCTF_' -and $_ -notmatch '^UNITF_'
    }
    return $filtered
}

function Get-RaEnumEntries {
    param([string]$EnumName)
    # Strip #ifdef CSII blocks for base RA roster
    $pattern = "typedef enum $EnumName[^}]+}"
    if ($defines -notmatch $pattern) { return @() }
    $block = $Matches[0]
    $lines = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in ($block -split "`n")) {
        if ($line -match '#ifdef FIXIT_CSII') { $skip = $true; continue }
        if ($line -match '#ifdef FIXIT_CARRIER') { $skip = $true; continue }
        if ($line -match '#ifdef FIXIT_ANTS') { $skip = $true; continue }
        if ($line -match '#ifdef FIXIT_PHASETRANSPORT') { $skip = $true; continue }
        if ($line -match '#endif') { $skip = $false; continue }
        if (-not $skip) { $lines.Add($line) }
    }
    $mini = $lines -join "`n"
    $entries = @()
    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t -match '^(\w+)\s*=') { $entries += $Matches[1] }
        elseif ($t -match '^(\w+)\s*,') { $entries += $Matches[1] }
        elseif ($t -match '^(\w+)\s*$' -and $t -notmatch 'enum|typedef') { $entries += $Matches[1] }
    }
    return $entries | Where-Object { $_ -notmatch '^(NONE|COUNT|FIRST|RA_COUNT)$' }
}

$typeEnums = [ordered]@{
    Infantry = Get-RaEnumEntries "InfantryType"
    Unit     = Get-RaEnumEntries "UnitType"
    Vessel   = Get-RaEnumEntries "VesselType"
    Aircraft = Get-RaEnumEntries "AircraftType"
    Building = Get-RaEnumEntries "StructType"
}

$classFiles = [ordered]@{
    INFANTRY = "INFANTRY.CPP"
    UNIT     = "UNIT.CPP"
    VESSEL   = "VESSEL.CPP"
    AIRCRAFT = "AIRCRAFT.CPP"
    BUILDING = "BUILDING.CPP"
}

function Get-FileMetrics {
    param([string]$FileName)
    $path = Join-Path $RedAlertDir $FileName
    if (-not (Test-Path $path)) {
        return @{
            ClassArrow = 0; SafeType = 0; DllIntercept = 0
            EternalSafe = 0; RepairEarly = 0; HasDrawIt = $false
        }
    }
    $text = Get-Content $path -Raw
    return @{
        ClassArrow   = ([regex]::Matches($text, 'Class->')).Count
        SafeType     = ([regex]::Matches($text, 'Aeloria_Safe_Techno_Type')).Count
        DllIntercept = ([regex]::Matches($text, 'DLL_Draw_Intercept')).Count
        EternalSafe  = ([regex]::Matches($text, 'Aeloria_IsEternalSafeProducedUnit')).Count
        RepairEarly  = ([regex]::Matches($text, 'Aeloria_Repair_Early_Class_Pointer')).Count
        HasDrawIt    = $text -match '::Draw_It\s*\('
    }
}

$objectH = Get-Content (Join-Path $RedAlertDir "OBJECT.H") -Raw
$technoCpp = Get-Content (Join-Path $RedAlertDir "TECHNO.CPP") -Raw
$dllIface = Get-Content (Join-Path $RedAlertDir "DLLInterface.cpp") -Raw
$conquer = Get-Content (Join-Path $RedAlertDir "CONQUER.CPP") -Raw

$layer1 = @{
    producedUnit     = $technoCpp -match 'producedUnit\s*='
    producedAircraft = $technoCpp -match 'producedAircraft\s*='
    producedVessel   = $technoCpp -match 'producedVessel\s*='
    producedInfantry = $technoCpp -match 'producedInfantry\s*='
    unlimboSeed      = $technoCpp -match 'producedUnitUnlimboSeeded\s*=\s*true'
}

$layer2 = @{}
foreach ($k in $classFiles.Keys) {
    $m = Get-FileMetrics $classFiles[$k]
    $score = "NONE"
    if ($m.DllIntercept -ge 3 -and $m.EternalSafe -ge 1) { $score = "FULL" }
    elseif ($m.DllIntercept -ge 1) { $score = "PARTIAL" }
    elseif ($m.HasDrawIt) { $score = "LEGACY" }
    $layer2[$k] = @{ Metrics = $m; Score = $score }
}

$eternalRtti = @()
if ($objectH -match 'RTTI_UNIT\s*&&\s*rtti\s*!=\s*RTTI_AIRCRAFT') { $eternalRtti += "UNIT,AIRCRAFT" }
if ($objectH -match 'RTTI_VESSEL') { $eternalRtti += "VESSEL" }

$vesselSafe = $dllIface -match 'case RTTI_VESSEL:\s*\{'
$layer3 = ($conquer -match 'Aeloria_NeedsSafeMainDrawGuard') -and ($conquer -match 'DLL_Draw_Intercept')

$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$totalRa = ($typeEnums.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum

$md = @()
$md += "# Full RA Roster - Crash Coverage Matrix"
$md += ""
$md += "Generated: $now by ``Scripts/Audit-AeloriaCoverage.ps1``"
$md += "Source: ``$RedAlertDir``"
$md += ""
$md += "## Summary"
$md += ""
$md += "| Metric | Value |"
$md += "|--------|-------|"
$md += "| Base RA roster entries | $totalRa |"
$md += "| Layer 3 (CC_Draw_Shape intercept) | $(if ($layer3) { 'YES' } else { 'NO' }) |"
$md += "| Layer 1 producedVessel tracking | $(if ($layer1.producedVessel) { 'YES' } else { 'NO' }) |"
$md += "| DLL VESSEL safe-type fallback | $(if ($vesselSafe) { 'YES' } else { 'NO' }) |"
$md += ""
$md += "## Three-Layer Defense Model"
$md += ""
$md += "| Layer | Scope | Status |"
$md += "|-------|-------|--------|"
$md += "| L1 Unlimbo tracking | TECHNO.CPP creation frame + stability flags | $(if ($layer1.unlimboSeed) { 'ACTIVE' } else { 'MISSING' }) |"
$md += "| L2 Per-class Draw_It | UNIT/AIRCRAFT/VESSEL/INFANTRY/BUILDING | see table below |"
$md += "| L3 CC_Draw_Shape | CONQUER.CPP universal intercept | $(if ($layer3) { 'ACTIVE' } else { 'MISSING' }) |"
$md += ""
$md += "> Layer 3 does **not** catch all pre-blitter paths inside Draw_It. Per-class L2 guards are mandatory for produced pool-reuse technos."
$md += ""
$md += "## Per-Class Coverage (Layer 2)"
$md += ""
$md += "| Class | Draw guard | Class-> count | Safe_Type count | DLL_Intercept | Eternal-safe ref | Verdict |"
$md += "|-------|------------|---------------|-----------------|---------------|------------------|---------|"

$verdictOrder = @{ FULL = 0; PARTIAL = 1; LEGACY = 2; NONE = 3 }
$gaps = @()

foreach ($k in $classFiles.Keys) {
    $m = $layer2[$k].Metrics
    $score = $layer2[$k].Score
    $md += "| $k | $(if ($m.HasDrawIt) { 'Draw_It' } else { '—' }) | $($m.ClassArrow) | $($m.SafeType) | $($m.DllIntercept) | $($m.EternalSafe) | **$score** |"
    if ($score -eq "LEGACY" -or ($score -eq "PARTIAL" -and $k -in @("VESSEL","AIRCRAFT","UNIT"))) {
        $gaps += "$k - $score (Class->=$($m.ClassArrow), Safe_Type=$($m.SafeType))"
    }
}

$md += ""
$md += "## Layer 1 - Unlimbo Seed Paths"
$md += ""
$md += "| Path | Present |"
$md += "|------|---------|"
foreach ($p in $layer1.Keys) {
    $md += "| $p | $(if ($layer1[$p]) { 'yes' } else { '**NO**' }) |"
}

$md += ""
$md += "## Full RA Roster by Category"
$md += ""
foreach ($cat in $typeEnums.Keys) {
    $md += "### $cat ($($typeEnums[$cat].Count) types)"
    $md += ""
    $md += ($typeEnums[$cat] -join ", ")
    $md += ""
}

$md += "## Prioritized Gap List"
$md += ""
if ($gaps.Count -eq 0) {
    $md += "- No LEGACY/PARTIAL gaps detected in primary techno Draw_It paths."
} else {
    $i = 1
    foreach ($g in $gaps) {
        $md += "$i. $g"
        $i++
    }
}
if (-not $layer1.producedVessel) {
    $md += "$($gaps.Count + 1). **5z-n10** - Add producedVessel Unlimbo seed + VESSEL Draw_It safe path (shipyard pool-reuse, same class as pre-n9 spy plane)."
}
if (-not $vesselSafe) {
    $md += "- DLLInterface RTTI_VESSEL returns raw Class without stability fallback."
}

$md += ""
$md += "## Cert Gate"
$md += ""
$md += "Matrix PASS requires: UNIT/AIRCRAFT/VESSEL Layer-2 = FULL, producedVessel = yes, gameplay cert checklist complete, soak max_frame >= 7500 with no AV."
$md += ""

$report = $md -join "`n"
Write-Output $report

if ($OutputMarkdown) {
    $outPath = if ([System.IO.Path]::IsPathRooted($OutputMarkdown)) {
        $OutputMarkdown
    } else {
        Join-Path $repoRoot $OutputMarkdown
    }
    $outDir = Split-Path $outPath -Parent
    if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    Set-Content -Path $outPath -Value $report -Encoding UTF8
    Write-Host "Wrote $outPath"
}

# Exit code: 0 = all primary classes FULL + producedVessel + vessel safe fallback
$allFull = ($layer2.UNIT.Score -eq "FULL") -and ($layer2.AIRCRAFT.Score -eq "FULL") -and ($layer2.VESSEL.Score -eq "FULL")
$ready = $allFull -and $layer1.producedVessel -and $vesselSafe
if (-not $ready) { exit 1 }
exit 0