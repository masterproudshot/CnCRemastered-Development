<#
.SYNOPSIS
    Auto-gate Aeloria Experimental soak sessions from collected debug logs.

.DESCRIPTION
    Parses Aeloria-Debug_*.log for north-star soak criteria (P1/P3/P4).
    Emits a single-line PASS/FAIL verdict and detailed gate breakdown.

.PARAMETER DebugLog
    Path to Aeloria-Debug log. If omitted, uses newest Logs\Aeloria-Debug_*.log.

.PARAMETER Profile
    P1 (5 min), P3 (20 min), or P4 (5 min no-debug expectations).

.PARAMETER LauncherLog
    Optional launcher log for crash-zip / session correlation.
#>
[CmdletBinding()]
param(
    [string]$DebugLog,
    [ValidateSet('P1','P3','P4')]
    [string]$Profile = 'P1',
    [string]$LauncherLog
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $repoRoot 'Logs'

if (-not $DebugLog) {
    $candidates = Get-ChildItem -Path $logDir -Filter 'Aeloria-Debug_*.log' -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending
    if (-not $candidates) {
        Write-Output 'FAIL: no Aeloria-Debug log found in Logs\'
        exit 2
    }
    $DebugLog = $candidates[0].FullName
}

if (-not (Test-Path -LiteralPath $DebugLog)) {
    Write-Output "FAIL: debug log not found: $DebugLog"
    exit 2
}

$content = Get-Content -LiteralPath $DebugLog -ErrorAction Stop
$lineCount = $content.Count

# Max logic frame (exclude last_bulk_frame= false positive)
$maxFrame = 0
foreach ($line in $content) {
    if ($line -match '(?<![a-z_])frame=(\d+)') {
        $f = [int]$Matches[1]
        if ($f -gt $maxFrame) { $maxFrame = $f }
    }
}

# Produced unit unlimbos (type_enum=2 is light tank in RA)
$tankUnlimbos = @($content | Where-Object { $_ -match 'PRODUCED_UNIT_UNLIMBO_SEED.*type_enum=2\b' })
$jeepUnlimbos = @($content | Where-Object { $_ -match 'PRODUCED_UNIT_UNLIMBO_SEED.*type_enum=1\b' })
$anyProducedUnlimbo = @($content | Where-Object { $_ -match 'PRODUCED_UNIT_UNLIMBO_SEED' })
$harvesterRelocate = @($content | Where-Object { $_ -match 'HARVESTER_STABILITY_RELOCATE' })
$lastHarvesterRelocateFrame = 0
foreach ($line in $harvesterRelocate) {
    if ($line -match 'frame=(\d+)') {
        $f = [int]$Matches[1]
        if ($f -gt $lastHarvesterRelocateFrame) { $lastHarvesterRelocateFrame = $f }
    }
}

$bulkStomp = @($content | Where-Object { $_ -match 'BULK_SLOT_STOMP_GUARD' })
$producedBulkDefer = @($content | Where-Object { $_ -match 'PRODUCED_UNIT_BULK_DEFER' })
$producedFirstDrawVirtual = @($content | Where-Object { $_ -match 'PRODUCED_UNIT_FIRST_DRAW.*window=VIRTUAL' })
$producedFirstDrawMain = @($content | Where-Object { $_ -match 'PRODUCED_UNIT_FIRST_DRAW.*window=MAIN' })
# STRUCT_WEAP enum value is 2 (not 21 — that is STRUCT_BARRACKS)
$wfBuilt = @($content | Where-Object { $_ -match 'BUILDING_GRAND_OPENING_COMPLETE.*type_enum=2\b' -or $_ -match 'CONSTRUCTION_COMPLETE.*type_enum=2\b' })

# Abrupt tail: log ends mid-burst without a recent graceful marker
$tailLines = if ($lineCount -ge 20) { $content[-20..-1] } else { $content }
$abruptTail = $true
foreach ($marker in @('FINAL STATE', 'CNC_Shutdown', 'GAME_OVER', 'PLAYER_EXIT')) {
    if ($content -match [regex]::Escape($marker)) { $abruptTail = $false; break }
}
# Heuristic: if max frame is high and last lines are routine draw/bulk, not necessarily abrupt
if ($maxFrame -ge 1000 -and $tailLines -match 'frame=') {
    $abruptTail = $false
}
# Post-nuke / mass-death cleanup burst without shutdown marker is a hard crash (P4 d83dc39b).
$trackingClearedTail = @($tailLines | Where-Object { $_ -match 'TRACKING_CLEARED' })
if ($trackingClearedTail.Count -ge 3) {
    $abruptTail = $true
}

$crashZip = $null
if ($LauncherLog -and (Test-Path -LiteralPath $LauncherLog)) {
    $crashMatch = Select-String -Path $LauncherLog -Pattern 'Crash report:' -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($crashMatch -and $crashMatch.Line -match 'Crash report:\s*(.+\.zip)') {
        $crashZip = $Matches[1].Trim()
    }
}

$gates = [ordered]@{}
switch ($Profile) {
    'P1' {
        $gates['max_frame_ge_7500'] = ($maxFrame -ge 7500)
        $gates['no_abrupt_tail'] = (-not $abruptTail)
        $gates['no_crash_zip'] = (-not $crashZip)
        if ($anyProducedUnlimbo.Count -gt 0 -or $wfBuilt.Count -gt 0) {
            $gates['tank_unlimbo_if_produced'] = ($tankUnlimbos.Count -ge 1)
        } else {
            $gates['tank_unlimbo_if_produced'] = $true  # WF not built — N/A pass
        }
        $gates['harvester_past_4546'] = ($maxFrame -gt 4546 -or $lastHarvesterRelocateFrame -eq 0 -or ($maxFrame -ge $lastHarvesterRelocateFrame + 100))
    }
    'P3' {
        $gates['max_frame_ge_27000'] = ($maxFrame -ge 27000)
        $gates['no_abrupt_tail'] = (-not $abruptTail)
        $gates['no_crash_zip'] = (-not $crashZip)
        $gates['tank_unlimbos_ge_2'] = ($tankUnlimbos.Count -ge 2)
        $gates['harvester_relocate_plus_100'] = ($lastHarvesterRelocateFrame -eq 0 -or ($maxFrame -ge $lastHarvesterRelocateFrame + 100))
    }
    'P4' {
        $gates['max_frame_ge_7500'] = ($maxFrame -ge 7500)
        $gates['no_abrupt_tail'] = (-not $abruptTail)
        $gates['no_crash_zip'] = (-not $crashZip)
        $gates['log_exists'] = $true
    }
}

$failed = @($gates.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
$pass = ($failed.Count -eq 0)

Write-Host "=== AELORIA SOAK ANALYSIS ($Profile) ===" -ForegroundColor Cyan
Write-Host "Log: $DebugLog"
Write-Host "Lines: $lineCount | MaxFrame: $maxFrame"
Write-Host "Tank unlimbos: $($tankUnlimbos.Count) | Jeep: $($jeepUnlimbos.Count) | Any produced: $($anyProducedUnlimbo.Count)"
Write-Host "Harvester relocate last frame: $lastHarvesterRelocateFrame | Bulk stomp: $($bulkStomp.Count)"
Write-Host "Produced first draw VIRTUAL/MAIN: $($producedFirstDrawVirtual.Count)/$($producedFirstDrawMain.Count)"
if ($crashZip) { Write-Host "Crash zip: $crashZip" -ForegroundColor Yellow }

foreach ($kv in $gates.GetEnumerator()) {
    $color = if ($kv.Value) { 'Green' } else { 'Red' }
    $mark = if ($kv.Value) { 'PASS' } else { 'FAIL' }
    Write-Host "  [$mark] $($kv.Key)" -ForegroundColor $color
}

$verdict = if ($pass) { "PASS" } else { "FAIL: $($failed -join ', ')" }
Write-Host "VERDICT: $verdict" -ForegroundColor $(if ($pass) { 'Green' } else { 'Red' })
Write-Output $verdict
exit $(if ($pass) { 0 } else { 1 })