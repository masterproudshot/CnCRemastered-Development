<#
.SYNOPSIS
    Project Aeloria launcher for Red Alert Remastered.

.DESCRIPTION
    Robust launcher with state machine, heavy logging, automatic DLL deployment,
    backups, and crash report capture.

Options:
  -P, -Profile <name>   Target profile (Experimental, Stable, or Vanilla-Plus).
                        Shows interactive selector if omitted.
  -D, -DebugMode        Launch the game with debug flags (MOD_DEBUG) and force Aeloria verbose draw
                        diagnostics logging on via AELORIA_ENABLE_VERBOSE_DRAW_LOGS=1 env var.
                        This makes the full per-object "got Object / guard passed / about-to-call" logs
                        appear in Aeloria_Debug.log.
                        **Strongly recommended for any long test, stability investigation, or custom map play.**
                        In debug mode the launcher uses immediate process-exit detection (Wait-Process).
                        As soon as you close the game, the script continues instantly with no polling delays.
                        The Aeloria debug log is automatically collected into the Logs\ folder with a matching
                        short ID for easy correlation with the launcher log.
  -B, -BuildFirst       Build the RedAlert project using MSBuild before deploying the DLL.
                        Prefers 2017-era MSBuild (for PlatformToolset=v145) when the VS 2017 C++ build tools
                        (v141/v145) components are installed via Visual Studio Installer. Always forces
                        /p:PlatformToolset=v145 for struct/ODR/early-object compatibility on custom maps.
                        Only activates if explicitly passed on the command line (no interactive prompt).
  -A, -AutoDeployDll    Auto-copy the newest built RedAlert.dll from Visual Studio
                        into the profile's Development folder.
                        When used together with -DebugMode it will also search Debug build folders
                        and the verbose logging env var will be active for the whole session.
  -NC, -NoCleanup       Leave the mod deployed to the live location after launch (no backup restore,
                        no removal of the deployed folder). Use this + -A to permanently update your
                        daily driver Aeloria-Stable for normal play via the .bat launcher.
  -F, -ForceCleanup     Force cleanup of backup and temp folders.
  -NC, -NoCleanup, -Permanent
                        Do not remove the deployed mod folder after the game exits.
                        Use this when you want a permanent install (e.g. daily Stable driver)
                        so that the simple .bat launchers keep working afterward.
  -h, -?                Show this help.

Environment (set automatically unless noted):
  AELORIA_QUIET         Non-debug perf throttle (E.2.50). Launcher sets **1** for normal play (no -D)
                        unless you already exported AELORIA_QUIET. Rate-limits CONSTRUCTION_SEED,
                        PRODUCED_UNIT_FIRST_DRAW, BUILDING_STAB_REFRESH, HARVESTER_* critical families.
                        Use -DebugMode (-D) for full guard trail; export AELORIA_QUIET=0 to disable quiet.
  AELORIA_ENABLE_VERBOSE_DRAW_LOGS
                        Set to 1 with -DebugMode; 0 for normal soak (P4).

WER / crash capture:
  After game exit the launcher waits **3s** before the first WER/Steam crash scrape (reports often
  land seconds after process exit), then polls again after 8s if nothing found.

Profiles:
  Experimental        - Latest changes, may be unstable. Use for active development.
  Stable              - Recommended for normal play. Good balance of features and stability.
  Vanilla-Plus        - Minimal changes, closest to vanilla with light QoL.

Note: After editing function.h / wwstd.h / packing headers, always Clean + Rebuild in Visual Studio.

IMPORTANT FOR TESTING: For any long session, custom map, or stability investigation, always use -DebugMode (-D).
This enables the rich per-object guard logging that is essential for diagnosing invisibility and exemption issues.
Without it you will only see the heavily rate-limited SEVERE messages.
#>

[CmdletBinding()]
param(
    [ValidateSet("Experimental","Stable","Vanilla-Plus")]
    [Alias("P")]
    [string]$Profile,

    [Alias("D")]
    [switch]$DebugMode,

    [Alias("B")]
    [switch]$BuildFirst,

    [Alias("F")]
    [switch]$ForceCleanup,

    [Alias("A")]
    [switch]$AutoDeployDll,

    # Do not remove the deployed mod folder from the live Documents location after the game exits.
    # Use this for "daily driver" Stable use so that simple .bat launchers continue to work afterward.
    [Alias("NC", "Permanent")]
    [switch]$NoCleanup,

    # Omit NO_EVENT_HANDLER (default P4 uses it for perf). Use for disconnect-popup diagnostics.
    [Alias("EH")]
    [switch]$WithEventHandler,

    # Agent/human soak ceiling; process exit ends wait early. Default 2h (NS long matches).
    [int]$SoakTimeoutSec = 7200
)

$ErrorActionPreference = "Stop"

# ====================== HELPER FUNCTIONS ======================

function Get-MSBuildPath {
    <#
    .SYNOPSIS
        Locates MSBuild.exe.
        We strongly prefer a 2017-era MSBuild if present (for v145 toolset),
        but will fall back to your current Visual Studio (e.g. VS 18/2022).
        The important part is that we ALWAYS force /p:PlatformToolset=v145 on the build.
        This requires that you have the VS 2017 (v141/v145) C++ build tools *components* installed
        via Visual Studio Installer (see Docs or the note printed on -B).
    #>
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

    if (Test-Path $vswhere) {
        try {
            # Try to find any VS 2017 installation first (best compatibility for early object / packing)
            $installPath = & $vswhere -version "[15.0,16.0)" -requires Microsoft.Component.MSBuild -property installationPath 2>$null | Select-Object -First 1
            if ($installPath) {
                $msbuild2017 = Join-Path $installPath "MSBuild\15.0\Bin\MSBuild.exe"
                if (Test-Path $msbuild2017) {
                    return $msbuild2017
                }
            }
        } catch {
            # vswhere failed, fall through
        }
    }

    # Hardcoded fallbacks (newest first, 2017 15.0 paths for when v141/v145 components are installed side-by-side)
    $candidates = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        # 2017-era (these will be present if you installed the v141/v145 components into a VS 2017 or side-by-side)
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Community\MSBuild\15.0\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Set-AeloriaVerboseDrawFlag {
    param(
        [Parameter(Mandatory = $true)][string]$ProfileRoot,
        [bool]$Enable
    )
    $flagPath = Join-Path $ProfileRoot "Data\AeloriaVerboseDraw.flag"
    if ($Enable) {
        $null = New-Item -ItemType Directory -Path (Split-Path $flagPath -Parent) -Force -ErrorAction SilentlyContinue
        Set-Content -LiteralPath $flagPath -Value "1" -Encoding ascii -Force
        Write-Log "Verbose draw flag ON (Steam -applaunch path): $flagPath" "INFO"
    } elseif (Test-Path -LiteralPath $flagPath) {
        Remove-Item -LiteralPath $flagPath -Force
        Write-Log "Verbose draw flag removed: $flagPath" "INFO"
    }
}

function Invoke-AutoDeployDll {
    Write-Log "AutoDeployDll requested - looking for newest RedAlert.dll in build output..." "INFO"

    # Hygiene: only auto-deploy into Stable when the user explicitly built first (-B).
    # Without -B, skip so a casual -A does not overwrite pinned Stable bits from stale output folders.
    if ($script:SelectedProfile.Name -eq "Aeloria-Stable" -and -not $BuildFirst) {
        Write-Log "AutoDeploy SKIPPED for Stable profile without -BuildFirst (use -P Stable -B -A -NC after editing source)." "WARN"
        return
    }
    if ($script:SelectedProfile.Name -eq "Vanilla-Plus" -and -not $BuildFirst) {
        Write-Log "AutoDeploy SKIPPED for Vanilla-Plus without -BuildFirst (prevents experimental DLL pollution)." "WARN"
        return
    }
    if ($script:SelectedProfile.Name -eq "Aeloria-Stable" -and $BuildFirst) {
        Write-Log "Stable profile + BuildFirst: auto-deploying freshly built DLL into Aeloria-Stable Development folder." "INFO"
    }

    if ($DebugMode) {
        Write-Log "  DebugMode active - will also search Debug build output folders (great when you build Debug config in VS)" "INFO"
    }

    $buildCandidates = @(
        # Release outputs (normal builds)
        "$ProjectRoot\Source\Rampastring-MoreQoL\bin\Win32\RedAlert.dll",
        "$ProjectRoot\Source\Rampastring-MoreQoL\bin\Release\RedAlert.dll",
        "$ProjectRoot\Source\Rampastring-MoreQoL\x86\Release\RedAlert.dll",
        # Debug outputs
        "$ProjectRoot\Source\Rampastring-MoreQoL\bin\Debug\RedAlert.dll",
        "$ProjectRoot\Source\Rampastring-MoreQoL\bin\Win32\Debug\RedAlert.dll",
        "$ProjectRoot\Source\Rampastring-MoreQoL\x86\Debug\RedAlert.dll"
    )

    $newestDll = $buildCandidates |
                 Where-Object { Test-Path $_ } |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1

    if ($newestDll) {
        $targetPath = Join-Path $script:SelectedProfile.DevPath "Data\RedAlert.dll"
        Copy-Item -Path $newestDll -Destination $targetPath -Force
        Write-Log "Auto-copied newest DLL -> $($script:SelectedProfile.Name) Development profile" "INFO"
        if ($DebugMode -and $newestDll -match '[\\/]Debug[\\/]') {
            Write-Log "  (picked from a Debug build output folder because -DebugMode was used)" "INFO"
        }
    } else {
        Write-Log "No built RedAlert.dll found in expected output folders. Using whatever exists in Development profile." "WARN"
    }

    # Step 5 from approved plan: post-deploy size check for reproducibility (bugfixer 411/audit hygiene).
    # Warn if Experimental profile got wrong size (e.g. pollution from other profile ~1.25M instead of ~1.27M).
    if ($script:SelectedProfile.Name -eq "Aeloria-Experimental") {
        $deployed = Join-Path $script:SelectedProfile.DevPath "Data\RedAlert.dll"
        if (Test-Path $deployed) {
            $len = (Get-Item $deployed).Length
            if ($len -lt 1270000 -or $len -gt 1310000) {
                Write-Log "WARNING: Experimental deployed DLL size $len (expected ~1.28-1.30M for infantry-scale builds). Possible profile pollution. Use explicit -Profile Experimental." "WARN"
            } else {
                Write-Log "Experimental DLL size OK ($len bytes) post-deploy." "INFO"
            }
        }
    }
}

# ====================== CONFIGURATION ======================
$ProjectRoot = "C:\Users\jacks\Documents\CnCRemastered\Development"
$SteamExe    = "C:\Program Files (x86)\Steam\steam.exe"
$ClientGExe  = "C:\Program Files (x86)\Steam\steamapps\common\CnCRemastered\ClientG.exe"
$ClientGDir  = "C:\Program Files (x86)\Steam\steamapps\common\CnCRemastered"
$AppId       = "1213210"

$LogDir      = Join-Path $ProjectRoot "Logs"
$CrashDir    = Join-Path $ProjectRoot "CrashReports"
$CrashSource = "$env:APPDATA\CnCRemastered"

$Profiles = @{
    "Experimental" = @{
        Name     = "Aeloria-Experimental"
        DevPath  = "$ProjectRoot\Mods\Red_Alert\Aeloria-Experimental"
        LivePath = "$env:USERPROFILE\Documents\CnCRemastered\Mods\Red_Alert\Aeloria-Experimental"
    }
    "Stable" = @{
        Name     = "Aeloria-Stable"
        DevPath  = "$ProjectRoot\Mods\Red_Alert\Aeloria-Stable"
        LivePath = "$env:USERPROFILE\Documents\CnCRemastered\Mods\Red_Alert\Aeloria-Stable"
    }
    "Vanilla-Plus" = @{
        Name     = "Vanilla-Plus"
        DevPath  = "$ProjectRoot\Mods\Red_Alert\Vanilla-Plus"
        LivePath = "$env:USERPROFILE\Documents\CnCRemastered\Mods\Red_Alert\Vanilla-Plus"
    }
}
# ===========================================================

# State Machine
enum LauncherState {
    Initializing
    DetectingProfile
    Building
    BackingUp
    Deploying
    Launching
    Monitoring
    CapturingCrash
    CleaningUp
    Completed
    Failed
}

$script:CurrentState = [LauncherState]::Initializing
$script:LogFile = $null
$script:BackupPath = $null
$script:SelectedProfile = $null
$script:LatestCrashReport = $null
$script:CollectedAeloriaDebugLog = $null

# Generate a short unique ID (8-4 hex format) similar to the Python script the user provided.
# Uses [guid]::NewGuid() + first 6 bytes for good per-session uniqueness.
function New-ShortLogId {
    $guid = [guid]::NewGuid()
    $bytes = $guid.ToByteArray()
    $selected = $bytes[0..5]
    $hex = ($selected | ForEach-Object { $_.ToString('x2') }) -join ''
    return "$($hex.Substring(0,8))-$($hex.Substring(8,4))"
}

function Set-State([LauncherState]$NewState) {
    $script:CurrentState = $NewState
    Write-Log "STATE TRANSITION -> $NewState" "STATE"
}

function Write-Log {
    param(
        [Parameter(Mandatory=$false)][AllowEmptyString()][string]$Message,
        [string]$Level = "INFO"
    )
    if ([string]::IsNullOrWhiteSpace($Message)) { return }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $line -ErrorAction SilentlyContinue
    }
}

function Initialize-Logging {
    if (-not (Test-Path $LogDir))  { New-Item -ItemType Directory -Path $LogDir  -Force | Out-Null }
    if (-not (Test-Path $CrashDir)) { New-Item -ItemType Directory -Path $CrashDir -Force | Out-Null }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'

    if ($script:DebugShortId) {
        # In debug mode, include the short ID for easy correlation with Aeloria debug logs
        $script:LogFile = Join-Path $LogDir "Launch-Aeloria_$($timestamp)_$($script:DebugShortId).log"
    } else {
        $script:LogFile = Join-Path $LogDir "Launch-Aeloria_$timestamp.log"
    }

    $script:SessionStartTime = Get-Date
    Write-Log "=== Project Aeloria Launcher Started ===" "INFO"
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"
    Write-Log "Running as Administrator: $([bool]([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))" "INFO"

    if ($script:DebugShortId) {
        Write-Log "Debug session short ID: $($script:DebugShortId)" "INFO"
    }
}

function Get-NewestProfile {
    Write-Log "Detecting profile with newest RedAlert.dll..." "INFO"
    $newest = $null
    $newestTime = [datetime]::MinValue

    foreach ($key in $Profiles.Keys) {
        $dllPath = Join-Path $Profiles[$key].DevPath "Data\RedAlert.dll"
        if (Test-Path $dllPath) {
            $time = (Get-Item $dllPath).LastWriteTime
            Write-Log "  Found DLL in $($Profiles[$key].Name): $dllPath (LastWrite: $time)" "DEBUG"
            if ($time -gt $newestTime) {
                $newestTime = $time
                $newest = $key
            }
        } else {
            Write-Log "  No DLL found for $($Profiles[$key].Name) at $dllPath" "DEBUG"
        }
    }

    if ($newest) {
        Write-Log "Newest profile detected: $newest" "INFO"
    } else {
        Write-Log "No profiles with a RedAlert.dll found." "WARN"
    }
    return $newest
}

function Backup-ExistingMod($livePath) {
    if (Test-Path $livePath) {
        $backupPath = "$livePath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Write-Log "Existing path found at $livePath. Backing up to $backupPath..." "WARN"
        try {
            Move-Item -Path $livePath -Destination $backupPath -Force -ErrorAction Stop
            Write-Log "Backup successful: $backupPath" "INFO"
            return $backupPath
        } catch {
            Write-Log "ERROR: Failed to backup existing path. $_" "ERROR"
            throw
        }
    }
    return $null
}

function Test-CnCGameRunning {
    $names = @('ClientG', 'InstanceServerG')
    $found = Get-Process -Name $names -ErrorAction SilentlyContinue
    if ($found) {
        Write-Log "CnC processes active: $($found.Name -join ', ') (PIDs: $($found.Id -join ', '))" "WARN"
        return $true
    }
    return $false
}

function Deploy-Profile($devPath, $livePath) {
    Write-Log "=== DEPLOY PHASE START ===" "INFO"
    Write-Log "Source: $devPath" "DEBUG"
    Write-Log "Destination: $livePath" "DEBUG"

    if (Test-CnCGameRunning) {
        Write-Log "ERROR: Refusing deploy while ClientG/InstanceServerG is running (prevents partial mod-folder delete mid-match)." "ERROR"
        throw "Deploy blocked: game is running"
    }

    if (-not (Test-Path $devPath)) {
        Write-Log "ERROR: Source profile does not exist: $devPath" "ERROR"
        throw "Source profile missing"
    }

    $sourceDll = Join-Path $devPath "Data\RedAlert.dll"
    if (-not (Test-Path $sourceDll)) {
        Write-Log "ERROR: No RedAlert.dll found in source Data folder: $sourceDll" "ERROR"
        throw "Missing RedAlert.dll in source"
    }
    Write-Log "Source DLL found: $sourceDll (Size: $((Get-Item $sourceDll).Length) bytes, Modified: $((Get-Item $sourceDll).LastWriteTime))" "INFO"

    if (Test-Path $livePath) {
        Write-Log "Destination already exists. Removing before copy..." "WARN"
        Remove-Item -Path $livePath -Recurse -Force -ErrorAction Stop
    }

    Write-Log "Copying entire profile..." "INFO"
    try {
        Copy-Item -Path $devPath -Destination $livePath -Recurse -Force -ErrorAction Stop
        Write-Log "Copy completed successfully." "INFO"
    } catch {
        Write-Log "ERROR during Copy-Item: $_" "ERROR"
        throw
    }

    # Verification
    $destDll = Join-Path $livePath "Data\RedAlert.dll"
    if (Test-Path $destDll) {
        $destLen = (Get-Item $destDll).Length
        Write-Log "Verification: Destination DLL exists ($destLen bytes)" "INFO"
        if ($script:SelectedProfile.Name -eq "Aeloria-Stable" -and $destLen -ge 1270000) {
            Write-Log "CRITICAL: Stable live DLL is $destLen bytes (experimental-sized). Wrong profile bits deployed!" "ERROR"
        }
    } else {
        Write-Log "ERROR: Destination DLL missing after copy!" "ERROR"
        throw "Deployment verification failed"
    }

    Write-Log "Deploy audit: DeployedProfile=$($script:SelectedProfile.Name) LiveDllBytes=$destLen" "INFO"
    Write-Log "=== DEPLOY PHASE COMPLETE ===" "INFO"
}

function Restore-Backup($backupPath, $livePath) {
    if ($backupPath -and (Test-Path $backupPath)) {
        Write-Log "Restoring backup from $backupPath..." "INFO"
        if (Test-Path $livePath) {
            Remove-Item $livePath -Recurse -Force -ErrorAction SilentlyContinue
        }
        Move-Item -Path $backupPath -Destination $livePath -Force
        Write-Log "Backup restored successfully." "INFO"
    }
}

function Capture-LatestCrashReport {
    param(
        [datetime]$NotOlderThan = $script:SessionStartTime
    )

    Write-Log "Checking for crash reports..." "INFO"
    if (-not (Test-Path $CrashSource)) {
        Write-Log "Crash source directory does not exist: $CrashSource" "DEBUG"
        return $null
    }

    $latest = Get-ChildItem -Path $CrashSource -Filter "*ServerG-exe_*.zip" -ErrorAction SilentlyContinue |
              Where-Object { $_.LastWriteTime -ge $NotOlderThan } |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        $latest = Get-ChildItem -Path $CrashSource -Filter "ClientG-exe_*.zip" -ErrorAction SilentlyContinue |
                  Where-Object { $_.LastWriteTime -ge $NotOlderThan } |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }

    if ($latest) {
        $destName = "Crash_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
        $destPath = Join-Path $CrashDir $destName
        Copy-Item -Path $latest.FullName -Destination $destPath -Force
        Write-Log "Captured crash report from this session: $destPath (source: $($latest.Name), $($latest.LastWriteTime))" "WARN"
        return $destPath
    }

    # WER archive fallback when Steam crash folder has no zip yet.
    $werRoot = Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive'
    if (Test-Path $werRoot) {
        $werLatest = Get-ChildItem -Path $werRoot -Directory -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match 'InstanceServerG|ClientG' -and $_.LastWriteTime -ge $NotOlderThan } |
                     Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($werLatest) {
            $destName = "Crash_WER_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $destPath = Join-Path $CrashDir $destName
            Copy-Item -Path $werLatest.FullName -Destination $destPath -Recurse -Force
            Write-Log "Captured WER crash report from this session: $destPath (source: $($werLatest.Name))" "WARN"
            return $destPath
        }
    }

    Write-Log "No crash reports from this session (ignoring stale zips before $NotOlderThan)." "INFO"
    return $null
}

function Wait-ForVisibleGameWindow {
    Write-Log "Waiting for visible game window to appear..." "INFO"

    $timeout = 120  # 2 minutes max to see a window
    $elapsed = 0
    $checkInterval = 1

    while ($elapsed -lt $timeout) {
        $gameProcesses = Get-Process -Name @("ClientG", "InstanceServerG") -ErrorAction SilentlyContinue |
                         Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match "Command & Conquer|Red Alert" }

        if ($gameProcesses) {
            Write-Log "Visible game window detected: $($gameProcesses[0].MainWindowTitle)" "INFO"
            return $true
        }

        Start-Sleep -Seconds $checkInterval
        $elapsed += $checkInterval
    }

    Write-Log "Timeout: No visible game window appeared." "WARN"
    return $false
}

function Test-SteamRunning {
    return $null -ne (Get-Process -Name "steam" -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Ensure-SteamReady {
    <#
    Returns @{ Ready = $bool; PreExisting = $bool }
    PreExisting=true  -> Steam was already running; direct ClientG.exe is safe (DRM authorized).
    PreExisting=false -> We started Steam; must use -applaunch after init wait (ClientG alone fails DRM).
    #>
    if (Test-SteamRunning) {
        Write-Log "Steam already running before launcher (direct ClientG eligible)." "INFO"
        return @{ Ready = $true; PreExisting = $true }
    }

    Write-Log "Steam not running - starting full client with -silent..." "INFO"
    Start-Process -FilePath $SteamExe -ArgumentList "-silent"

    $timeoutSec = 90
    $elapsed = 0
    while ($elapsed -lt $timeoutSec) {
        if (Test-SteamRunning) {
            Write-Log "Steam process detected after ${elapsed}s." "INFO"
            break
        }
        Start-Sleep -Seconds 2
        $elapsed += 2
    }

    if (-not (Test-SteamRunning)) {
        Write-Log "Steam did not start within ${timeoutSec}s." "WARN"
        return @{ Ready = $false; PreExisting = $false }
    }

    # ClientG.exe requires Steam login/DRM init; 5s was too short (Steam Required popup).
    Write-Log "Waiting 25s for Steam login/DRM init before -applaunch..." "INFO"
    Start-Sleep -Seconds 25
    return @{ Ready = $true; PreExisting = $false }
}

function Stop-StaleCnCProcesses {
    $names = @('ClientG', 'InstanceServerG')
    $found = Get-Process -Name $names -ErrorAction SilentlyContinue
    if (-not $found) { return }
    Write-Log "Stopping stale CnC processes before launch: $($found.Name -join ', ')" "WARN"
    $found | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}

function Start-CnCRemasteredGame {
    param([string]$LaunchArgs)

    Stop-StaleCnCProcesses
    $steam = Ensure-SteamReady

    # Always -applaunch from the ps1 dev launcher. Direct ClientG.exe can fail DRM even when
    # steam.exe is present (partial bootstrap). Pre-starting Steam with -silent then -applaunch
    # keeps the full client open after game exit; relaunches skip the 25s init wait when PreExisting.
    if ($steam.Ready) {
        if ($steam.PreExisting) {
            Write-Log "Steam already running; brief settle wait after stale-process cleanup..." "INFO"
            Start-Sleep -Seconds 5
            Write-Log "Launching via Steam -applaunch (Steam already running; fast relaunch path): $LaunchArgs" "INFO"
        } else {
            Write-Log "Launching via Steam -applaunch (after pre-started client + DRM init wait): $LaunchArgs" "INFO"
        }
        Start-Process -FilePath $SteamExe -ArgumentList "-applaunch $AppId $LaunchArgs"
    } else {
        Write-Log "Launching via cold Steam -applaunch fallback: $LaunchArgs" "WARN"
        Start-Process -FilePath $SteamExe -ArgumentList "-applaunch $AppId $LaunchArgs"
    }
}

function Wait-ForGameExit {
    Write-Log "=== MONITORING PHASE ===" "INFO"

    # First, wait until we actually see a game window
    $windowVisible = Wait-ForVisibleGameWindow
    $script:GameWindowWasVisible = [bool]$windowVisible

    if (-not $windowVisible) {
        Write-Log "No game window ever appeared. Assuming launch failure." "WARN"
        return
    }

    Write-Log "Game window is visible. Now monitoring for clean exit..." "INFO"

    $processes = @("ClientG", "InstanceServerG")
    $timeoutSeconds = $SoakTimeoutSec

    Write-Log "Monitoring via Wait-Process (timeout ${timeoutSeconds}s)." "INFO"
    Wait-Process -Name $processes -ErrorAction SilentlyContinue -Timeout $timeoutSeconds
    Write-Log "Game processes have exited (or soak timeout reached)." "INFO"
}

# ====================== MAIN EXECUTION ======================

# Session short ID for log naming/correlation (P4 critical logs land in USERPROFILE even without -D).
$script:DebugShortId = New-ShortLogId

Initialize-Logging
Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::Initializing)

try {
    Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::DetectingProfile)

    $recommended = Get-NewestProfile

    if (-not $Profile) {
        Write-Host "`nAvailable profiles:"
        $i=1; $list=@()
        foreach ($k in $Profiles.Keys) {
            $m = if ($k -eq $recommended) { " (recommended)" } else { "" }
            Write-Host "  $i) $k$m"
            $list += $k; $i++
        }
        $sel = Read-Host "`nSelect profile (1-$($list.Count))"
        # Prefer explicit or Stable/Experimental over "newest by mtime" to protect pinned Stable bits for .bat daily driver.
        $Profile = if ($sel -match '^\d+$' -and [int]$sel -in 1..$list.Count) { $list[[int]$sel-1] } else { if ($recommended) { $recommended } else { "Stable" } }
    }

    if (-not $Profiles.ContainsKey($Profile)) {
        Write-Log "Invalid profile selected: $Profile" "ERROR"
        exit 1
    }

    $script:SelectedProfile = $Profiles[$Profile]
    Write-Log "Final selected profile: $($script:SelectedProfile.Name)" "INFO"
    # Hygiene guard: if user asked for Stable but we ended up on Experimental (mtime or default bug), warn loudly.
    if ($Profile -eq "Stable" -and $script:SelectedProfile.Name -ne "Aeloria-Stable") {
        Write-Log "HYGIENE WARNING: Requested Stable but selected $($script:SelectedProfile.Name). Re-run with explicit -Profile Stable." "WARN"
    }

    $script:NoCleanup = $NoCleanup
    if ($script:NoCleanup) {
        Write-Log "-NoCleanup / -Permanent requested. Live mod folder will NOT be removed after exit." "INFO"
    }

    $script:IsDebugMode = $DebugMode

    # NoCleanup / NC: when set, we deploy (if -A) but leave the live mod folder in place after the session
    # so that Launch-Aeloria-Stable.bat (or Steam MOD=) will continue to use the updated bits for normal play.
    $script:NoCleanup = $NoCleanup
    if ($script:NoCleanup) {
        Write-Log "NoCleanup mode: deployed mod will be left in the live location (no restore at end)." "INFO"
    }

    # Debug mode decision + env var setup - do this *very early* (right after profile)
    # so that -AutoDeployDll, -BuildFirst, and every later step can react to it.
    # Note: We no longer prompt interactively. Pass -DebugMode (or -D) explicitly if desired.

    # infantry-scale Phase 2: zero-map produced infantry (set AELORIA_ZERO_MAP_PRODUCED_INFANTRY=0 before launch to disable).
    if (-not $env:AELORIA_ZERO_MAP_PRODUCED_INFANTRY) {
        $env:AELORIA_ZERO_MAP_PRODUCED_INFANTRY = "1"
    }
    Write-Log "AELORIA_ZERO_MAP_PRODUCED_INFANTRY=$($env:AELORIA_ZERO_MAP_PRODUCED_INFANTRY) (infantry-scale Phase 2)" "INFO"

    if ($script:DebugShortId) {
        $env:AELORIA_LOG_SESSION_ID = $script:DebugShortId
    }
    if ($DebugMode) {
        $env:AELORIA_ENABLE_VERBOSE_DRAW_LOGS = "1"
        Write-Log "DebugMode is active for this session: AELORIA_ENABLE_VERBOSE_DRAW_LOGS=1 (verbose draw logs will be enabled in the DLL)" "INFO"
    } else {
        # Explicitly set to "0" so child processes (Steam + game) definitely see verbose logging as OFF.
        # This is more reliable than just Remove-Item for ensuring normal play is silent.
        $env:AELORIA_ENABLE_VERBOSE_DRAW_LOGS = "0"
        Write-Log "Normal (non-Debug) session: AELORIA_ENABLE_VERBOSE_DRAW_LOGS explicitly set to 0 (verbose draw logs should be suppressed)" "INFO"
        # E.2.50: non-debug perf — quiet critical log families unless user already set AELORIA_QUIET.
        if (-not $env:AELORIA_QUIET) {
            $env:AELORIA_QUIET = "1"
        }
        Write-Log "Normal (non-Debug) session: AELORIA_QUIET=$($env:AELORIA_QUIET) (rate-limits CONSTRUCTION_SEED/PRODUCED_UNIT_FIRST_DRAW/BUILDING_STAB_REFRESH/HARVESTER_ critical logs)" "INFO"
    }

    # Stage newest built DLL into the Development profile before copying to live.
    # -A alone: stage from last build output. -B: always re-stage after MSBuild (even without -A).
    $ShouldAutoDeployNow = $AutoDeployDll -and -not $BuildFirst

    if ($ShouldAutoDeployNow) {
        Invoke-AutoDeployDll
    }

    # Build first?
    # Only build if -BuildFirst was explicitly passed on the command line.
    # We no longer prompt for this - if you want a build, pass the flag.
    if ($BuildFirst) {
        Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::Building)
        $solutionPath = "$ProjectRoot\Source\Rampastring-MoreQoL\CnCRemastered.sln"

        $msbuildPath = Get-MSBuildPath
        if (-not $msbuildPath) {
            Write-Log "ERROR: Could not locate MSBuild.exe." "ERROR"
            Write-Log "Please install Visual Studio (with MSBuild workload) or the standalone Build Tools." "ERROR"
            Write-Log "For best compatibility with early object creation and custom 4p skirmish (struct layout, vtable, RTTI), install the VS 2017 C++ build tools components:" "ERROR"
            Write-Log "  Visual Studio Installer -> Modify your VS 18/2022 -> Individual components -> search 'v141' or '2017' -> 'MSVC v141 - VS 2017 C++ x86/x64 build tools'." "ERROR"
            throw "MSBuild.exe not found on this system."
        }

        # Always force PlatformToolset=v145 (2017-era) for struct packing / ODR / early-RTTI-object compatibility.
        # When running in DebugMode (-D), force a full Rebuild instead of incremental Build.
        $msbuildArgs = "`"$solutionPath`" /t:RedAlert /p:Configuration=Release /p:Platform=x86 /p:PlatformToolset=v145 /verbosity:minimal /nologo"
        if ($DebugMode) {
            Write-Log "DebugMode active - forcing full Rebuild of RedAlert project (not incremental)." "INFO"
        }
        Write-Log "Starting MSBuild for RedAlert project (forcing PlatformToolset=v145 for 2017-era struct/early-object compatibility)..." "INFO"
        Write-Log "Using MSBuild: $msbuildPath" "INFO"
        if ($msbuildPath -notmatch '2017|15\.0') {
            Write-Log "NOTE: Using modern MSBuild (VS 18/2022+). This works if the VS 2017 C++ v141/v145 components are installed via the Installer (Individual components)." "INFO"
        }
        Write-Log "Command: `"$msbuildPath`" $msbuildArgs" "INFO"

        try {
            $effectiveTarget = if ($DebugMode) { "RedAlert:Rebuild" } else { "RedAlert" }
            $msbuildOutput = & $msbuildPath "$solutionPath" /t:$effectiveTarget /p:Configuration=Release /p:Platform=x86 /p:PlatformToolset=v145 /verbosity:minimal /nologo 2>&1
            $exitCode = $LASTEXITCODE

            if ($msbuildOutput) {
                $msbuildOutput | ForEach-Object {
                    $msg = $_ -as [string]
                    if (-not [string]::IsNullOrWhiteSpace($msg)) {
                        Write-Log $msg "MSBUILD"
                    }
                }
            }

            if ($exitCode -ne 0) {
                Write-Log "MSBuild failed with exit code $exitCode." "ERROR"
                throw "Build failed with exit code $exitCode. Check the MSBUILD lines above for errors."
            }

            Write-Log "MSBuild succeeded (exit code 0)." "INFO"

            # Always stage the fresh build into the Development profile so -B -NC cannot deploy a stale Dev DLL.
            Write-Log "Build completed successfully - staging fresh DLL into Development profile..." "INFO"
            Invoke-AutoDeployDll
            Set-AeloriaVerboseDrawFlag -ProfileRoot $script:SelectedProfile.DevPath -Enable:([bool]$DebugMode)
        } catch {
            Write-Log "ERROR during build step: $_" "ERROR"
            throw
        }
    }

    # Backup + Deploy
    if ($script:NoCleanup) {
        Write-Log "NoCleanup / Permanent mode: skipping backup of existing live folder." "INFO"
        $script:BackupPath = $null
    } else {
        Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::BackingUp)
        $script:BackupPath = Backup-ExistingMod $script:SelectedProfile.LivePath
    }

    Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::Deploying)
    if (-not $BuildFirst) {
        Set-AeloriaVerboseDrawFlag -ProfileRoot $script:SelectedProfile.DevPath -Enable:([bool]$DebugMode)
    }
    Deploy-Profile $script:SelectedProfile.DevPath $script:SelectedProfile.LivePath

    # Quick post-deploy verification (especially useful for -NoCleanup / Experimental)
    $liveGc = Join-Path $script:SelectedProfile.LivePath "GameConstants_Mod.xml"
    if (Test-Path $liveGc) {
        $gcSize = (Get-Item $liveGc).Length
        $zoomCount = (Get-Content $liveGc | Select-String "ZoomFactor" | Measure-Object).Count
        Write-Log "Post-deploy check: GameConstants_Mod.xml size=$gcSize bytes, ZoomFactor count=$zoomCount" "INFO"
    }

    $liveDll = Join-Path $script:SelectedProfile.LivePath "Data\RedAlert.dll"
    if (Test-Path $liveDll) {
        $dllInfo = Get-Item $liveDll
        Write-Log "Post-deploy check: RedAlert.dll size=$($dllInfo.Length) bytes, Modified=$($dllInfo.LastWriteTime)" "INFO"
    }

    # Launch
    Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::Launching)

    $launchArgs = "REDALERT MOD=$($script:SelectedProfile.Name) -FastLaunch"
    if (-not $WithEventHandler) {
        $launchArgs += " NO_EVENT_HANDLER"
    }
    if ($DebugMode) {
        $launchArgs += " MOD_DEBUG"
        Write-Log "Debug flags (MOD_DEBUG) added to launch arguments. (Verbose logging env var was already set for the whole session above.)" "INFO"
    } elseif ($WithEventHandler) {
        Write-Log "WithEventHandler: NO_EVENT_HANDLER omitted (event handler enabled for this session)." "INFO"
    } else {
        Write-Log "P4 perf: NO_EVENT_HANDLER on (use -WithEventHandler to omit; -D adds MOD_DEBUG)." "INFO"
    }

    Write-Log "Launch arguments: $launchArgs" "INFO"
    Start-CnCRemasteredGame -LaunchArgs $launchArgs

    # Monitor
    Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::Monitoring)
    Wait-ForGameExit

    # Capture crash report (WER/Steam zips often land a few seconds after process exit).
    Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::CapturingCrash)
    Start-Sleep -Seconds 3
    $script:LatestCrashReport = Capture-LatestCrashReport
    if (-not $script:LatestCrashReport) {
        Write-Log "No crash zip yet; polling WER/Steam once more after 8s..." "INFO"
        Start-Sleep -Seconds 8
        $script:LatestCrashReport = Capture-LatestCrashReport
    }

} catch {
    Write-Log "FATAL ERROR: $_" "ERROR"
    $script:CurrentState = [LauncherState]::Failed
} finally {
    Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::CleaningUp)
    Write-Log "Entering cleanup phase..." "INFO"

    if ($script:SelectedProfile -and (Test-Path $script:SelectedProfile.LivePath)) {
        if ($script:NoCleanup) {
            Write-Log "NoCleanup mode: leaving deployed folder at $($script:SelectedProfile.LivePath) (for daily driver use via .bat / Steam MOD=)." "INFO"
        } else {
            Remove-Item $script:SelectedProfile.LivePath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Deployed folder removed." "INFO"
        }
    }

    if (-not $script:NoCleanup) {
        Restore-Backup $script:BackupPath $script:SelectedProfile.LivePath
    } else {
        Write-Log "NoCleanup mode: skipping restore of previous backup (keeping fresh deploy)." "INFO"
        if ($script:BackupPath -and (Test-Path $script:BackupPath)) {
            Write-Log "Backup left at: $($script:BackupPath) (not restored due to -NoCleanup)" "INFO"
        }
    }

    if ($script:LatestCrashReport) {
        Write-Log "Latest crash report available at: $($script:LatestCrashReport)" "WARN"
    }

    # Always collect USERPROFILE Aeloria debug log when a skirmish ran (critical breadcrumbs
    # are logged even without -D). Full verbose draw requires -D.
    if ($script:DebugShortId -and $script:GameWindowWasVisible) {
        $aeloriaLogPatterns = @(
            "$env:USERPROFILE\Aeloria-Debug-*.log",
            "C:\Users\jacks\Aeloria-Debug-*.log",
            ".\Aeloria-Debug-*.log",
            "$LogDir\Aeloria-Debug-*.log"
        )

        $foundLog = $null
        $launchStartTime = (Get-Item $script:LogFile).CreationTime

        # E.2.13e: DLL attach log proves whether RedAlert.dll loaded (menu-only exits often have neither).
        $dllAttachPatterns = @(
            "$env:USERPROFILE\Aeloria-DllAttach-*.log",
            ".\Aeloria-DllAttach-*.log",
            "$LogDir\Aeloria-DllAttach-*.log"
        )
        $foundAttachLog = $null
        foreach ($pattern in $dllAttachPatterns) {
            $attachCandidates = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue |
                                Where-Object { $_.LastWriteTime -gt $launchStartTime.AddMinutes(-2) } |
                                Sort-Object LastWriteTime -Descending
            if ($attachCandidates) {
                $foundAttachLog = $attachCandidates[0]
                break
            }
        }
        if ($foundAttachLog) {
            $attachDest = Join-Path $LogDir ("Aeloria-DllAttach_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($script:DebugShortId).log")
            try {
                Copy-Item -Path $foundAttachLog.FullName -Destination $attachDest -Force -ErrorAction Stop
                Write-Log "Collected Aeloria DLL attach log -> $attachDest" "INFO"
                Get-Content -LiteralPath $attachDest -Tail 5 -ErrorAction SilentlyContinue | ForEach-Object {
                    Write-Log "  DLL_ATTACH: $_" "INFO"
                }
            } catch {
                Write-Log "WARN: Failed to collect DLL attach log from $($foundAttachLog.FullName): $_" "WARN"
            }
        } elseif ($script:GameWindowWasVisible) {
            Write-Log "WARN: No Aeloria-DllAttach log this session - RedAlert.dll never loaded (title-menu-only exit or ClientG crash)." "WARN"
        }

        foreach ($pattern in $aeloriaLogPatterns) {
            $candidates = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue |
                          Where-Object { $_.LastWriteTime -gt $launchStartTime.AddMinutes(-2) } |
                          Sort-Object LastWriteTime -Descending

            if ($candidates) {
                $foundLog = $candidates[0]
                break
            }
        }

        if ($foundLog) {
            $newName = "Aeloria-Debug_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($script:DebugShortId).log"
            $destPath = Join-Path $LogDir $newName
            $collected = $false
            foreach ($attempt in 1..5) {
                try {
                    Move-Item -Path $foundLog.FullName -Destination $destPath -Force -ErrorAction Stop
                    $collected = $true
                    break
                } catch {
                    if ($attempt -lt 5) {
                        Start-Sleep -Seconds 2
                        continue
                    }
                    try {
                        Copy-Item -Path $foundLog.FullName -Destination $destPath -Force -ErrorAction Stop
                        $collected = $true
                        Write-Log "Collected Aeloria debug log via copy (move failed: locked file)." "WARN"
                    } catch {
                        Write-Log "WARNING: Failed to collect Aeloria debug log from $($foundLog.FullName): $_" "WARN"
                    }
                }
            }
            if ($collected) {
                $script:CollectedAeloriaDebugLog = $destPath
                Write-Log "Collected Aeloria debug log -> $destPath" "INFO"
                Write-Host "Aeloria Debug Log: $destPath" -ForegroundColor Cyan
            }

            # Always try to show a tail of the debug log on the console (on its own clear lines)
            # so that when the user pastes the launcher output, we get the recent Aeloria
            # breadcrumbs (PRE_PLACEHOLDER, PLACEHOLDER_*, HARD_REJECT, ages, stability, etc.)
            # with zero extra steps. Uses plain ASCII and limited tail to avoid huge output.
            if (Test-Path -LiteralPath $destPath) {
                Write-Host ""
                Write-Host ">>> AELORIA DEBUG LOG TAIL (last 250 lines - include when reporting crashes):" -ForegroundColor Yellow
                try {
                    Get-Content -LiteralPath $destPath -Tail 250 -ErrorAction Stop | ForEach-Object { Write-Host "    $_" }
                } catch {
                    Write-Host "    (could not read tail of debug log)" -ForegroundColor DarkYellow
                }
                Write-Host "### END AELORIA DEBUG LOG TAIL ###" -ForegroundColor Yellow
            }

            # Phase P0/P4: auto-analyze soak gates when debug log was collected.
            $analyzeScript = Join-Path $PSScriptRoot "Analyze-AeloriaSoak.ps1"
            if (Test-Path -LiteralPath $analyzeScript) {
                try {
                    $soakProfile = if ($script:IsDebugMode) { 'P1' } else { 'P4' }
                    Write-Host ""
                    Write-Host ">>> AELORIA SOAK AUTO-ANALYSIS ($soakProfile gates):" -ForegroundColor Cyan
                    & $analyzeScript -DebugLog $destPath -Profile $soakProfile -LauncherLog $script:LogFile
                    if ($script:LogFile -and (Test-Path -LiteralPath $script:LogFile)) {
                        $werInLauncher = Select-String -Path $script:LogFile -Pattern 'Captured WER crash report|Crash_WER_' -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($werInLauncher) {
                            Write-Host "FAIL: crash_wer_captured - WER crash report was archived this session (see launcher log)." -ForegroundColor Red
                        }
                    }
                } catch {
                    Write-Log "WARN: Analyze-AeloriaSoak.ps1 failed: $_" "WARN"
                }
            }
        } else {
            if ($script:GameWindowWasVisible) {
                Write-Log "WARN: Debug session ended without Aeloria debug log - DLL may not have loaded, or skirmish was not started." "WARN"
                Write-Host "WARN: No Aeloria debug log collected (game window was visible). Start a skirmish for full diagnostics." -ForegroundColor Yellow
                $rawProbe = Get-ChildItem -Path "$env:USERPROFILE\Aeloria-Debug-*.log" -ErrorAction SilentlyContinue |
                            Sort-Object LastWriteTime -Descending | Select-Object -First 3
                if ($rawProbe) {
                    Write-Log "Recent raw USERPROFILE Aeloria-Debug logs (for diagnosis):" "WARN"
                    $rawProbe | ForEach-Object { Write-Log "  $($_.FullName) mtime=$($_.LastWriteTime)" "WARN" }
                }
            } else {
                Write-Log "No recent Aeloria debug log found to collect." "DEBUG"
            }
        }
    }

    Write-Log "=== FINAL STATE: $($script:CurrentState) ===" "INFO"
    Write-Host "`n=== LAUNCHER SESSION SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Log file: $($script:LogFile)" -ForegroundColor White
    if ($script:CollectedAeloriaDebugLog) {
        Write-Host "Aeloria Debug Log: $($script:CollectedAeloriaDebugLog)" -ForegroundColor Cyan
    }
    if ($script:LatestCrashReport) {
        Write-Host "Crash report: $($script:LatestCrashReport)" -ForegroundColor Yellow
    }
    Write-Host "State: $($script:CurrentState)" -ForegroundColor Green
    if ($script:NoCleanup) {
        Write-Host "NoCleanup/Permanent mode was used - mod left in live folder for .bat use." -ForegroundColor Yellow
    }
    if ($script:DebugShortId) {
        Write-Host "Debug short ID: $($script:DebugShortId)" -ForegroundColor Cyan
        Write-Host "  See the two log paths listed directly above in this summary." -ForegroundColor DarkGray
    }
}