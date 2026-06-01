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
                        Auto-detects MSBuild.exe (prefers vswhere, falls back to common VS 2019/2022 paths).
                        Only activates if explicitly passed on the command line (no interactive prompt).
  -A, -AutoDeployDll    Auto-copy the newest built RedAlert.dll from Visual Studio
                        into the profile's Development folder.
                        When used together with -DebugMode it will also search Debug build folders
                        and the verbose logging env var will be active for the whole session.
  -F, -ForceCleanup     Force cleanup of backup and temp folders.
  -NC, -NoCleanup, -Permanent
                        Do not remove the deployed mod folder after the game exits.
                        Use this when you want a permanent install (e.g. daily Stable driver)
                        so that the simple .bat launchers keep working afterward.
  -h, -?                Show this help.

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
    [switch]$NoCleanup
)

$ErrorActionPreference = "Stop"

# ====================== HELPER FUNCTIONS ======================

function Get-MSBuildPath {
    <#
    .SYNOPSIS
        Locates MSBuild.exe from Visual Studio or Build Tools installation.
        Tries vswhere first (most reliable), then falls back to common paths.
    #>
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

    if (Test-Path $vswhere) {
        try {
            $installPath = & $vswhere -latest -requires Microsoft.Component.MSBuild -property installationPath 2>$null | Select-Object -First 1
            if ($installPath) {
                $msbuild = Join-Path $installPath "MSBuild\Current\Bin\MSBuild.exe"
                if (Test-Path $msbuild) {
                    return $msbuild
                }
            }
        } catch {
            # vswhere failed, fall through to hardcoded paths
        }
    }

    # Common fallback locations (VS 2022 and 2019)
    $candidates = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe"
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Invoke-AutoDeployDll {
    Write-Log "AutoDeployDll requested - looking for newest RedAlert.dll in build output..." "INFO"

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
}

# ====================== CONFIGURATION ======================
$ProjectRoot = "C:\Users\jacks\Documents\CnCRemastered\Development"
$SteamExe    = "C:\Program Files (x86)\Steam\steam.exe"
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

function Deploy-Profile($devPath, $livePath) {
    Write-Log "=== DEPLOY PHASE START ===" "INFO"
    Write-Log "Source: $devPath" "DEBUG"
    Write-Log "Destination: $livePath" "DEBUG"

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
        Write-Log "Verification: Destination DLL exists ($((Get-Item $destDll).Length) bytes)" "INFO"
    } else {
        Write-Log "ERROR: Destination DLL missing after copy!" "ERROR"
        throw "Deployment verification failed"
    }

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
    Write-Log "Checking for crash reports..." "INFO"
    if (-not (Test-Path $CrashSource)) {
        Write-Log "Crash source directory does not exist: $CrashSource" "DEBUG"
        return $null
    }

    $latest = Get-ChildItem -Path $CrashSource -Filter "InstanceServerG-exe_*.zip" -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($latest) {
        $destName = "Crash_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
        $destPath = Join-Path $CrashDir $destName
        Copy-Item -Path $latest.FullName -Destination $destPath -Force
        Write-Log "Captured latest crash report: $destPath" "WARN"
        return $destPath
    }
    Write-Log "No crash reports found." "INFO"
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

function Wait-ForGameExit {
    Write-Log "=== MONITORING PHASE ===" "INFO"

    # First, wait until we actually see a game window
    $windowVisible = Wait-ForVisibleGameWindow

    if (-not $windowVisible) {
        Write-Log "No game window ever appeared. Assuming launch failure." "WARN"
        return
    }

    Write-Log "Game window is visible. Now monitoring for clean exit..." "INFO"

    $processes = @("ClientG", "InstanceServerG")
    $timeoutSeconds = 900   # 15 minutes max play session

    # In debug mode we want *immediate* detection the moment you close the game.
    # No polling delays, no minimum runtime guard. The launcher should react instantly.
    if ($script:IsDebugMode) {
        Write-Log "Debug mode: using immediate process exit detection (no delays)." "INFO"

        # Wait-Process blocks until the named processes are gone.
        # This gives near-instant reaction when you exit the game.
        Wait-Process -Name $processes -ErrorAction SilentlyContinue -Timeout $timeoutSeconds

        Write-Log "Game processes have exited (detected immediately)." "INFO"
        return
    }

    # === Normal (non-debug) path ===
    $checkInterval = 3
    $elapsed = 0

    while ($elapsed -lt $timeoutSeconds) {
        $running = Get-Process -Name $processes -ErrorAction SilentlyContinue

        if (-not $running) {
            # The game processes are gone. Exit the monitoring immediately.
            # No "too early" waiting or artificial delays when you intentionally close the game.
            Write-Log "Game processes have exited (detected immediately)." "INFO"
            return
        }

        Start-Sleep -Seconds $checkInterval
        $elapsed += $checkInterval

        if ($elapsed % 30 -eq 0) {
            Write-Log "Game still running... ($elapsed seconds visible runtime)" "DEBUG"
        }
    }

    Write-Log "Timeout reached while game was still running." "WARN"
}

# ====================== MAIN EXECUTION ======================

# Generate short ID early for debug sessions (used for log naming and correlation)
if ($DebugMode) {
    $script:DebugShortId = New-ShortLogId
} else {
    $script:DebugShortId = $null
}

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
        $Profile = if ($sel -match '^\d+$' -and [int]$sel -in 1..$list.Count) { $list[[int]$sel-1] } else { $list[0] }
    }

    if (-not $Profiles.ContainsKey($Profile)) {
        Write-Log "Invalid profile selected: $Profile" "ERROR"
        exit 1
    }

    $script:SelectedProfile = $Profiles[$Profile]
    Write-Log "Final selected profile: $($script:SelectedProfile.Name)" "INFO"

    $script:NoCleanup = $NoCleanup
    if ($script:NoCleanup) {
        Write-Log "-NoCleanup / -Permanent requested. Live mod folder will NOT be removed after exit." "INFO"
    }

    $script:IsDebugMode = $DebugMode

    # Debug mode decision + env var setup - do this *very early* (right after profile)
    # so that -AutoDeployDll, -BuildFirst, and every later step can react to it.
    # Note: We no longer prompt interactively. Pass -DebugMode (or -D) explicitly if desired.

    if ($DebugMode) {
        $env:AELORIA_ENABLE_VERBOSE_DRAW_LOGS = "1"
        if ($script:DebugShortId) {
            $env:AELORIA_LOG_SESSION_ID = $script:DebugShortId
        }
        Write-Log "DebugMode is active for this session: AELORIA_ENABLE_VERBOSE_DRAW_LOGS=1 (verbose draw logs will be enabled in the DLL)" "INFO"
    } else {
        # Explicitly set to "0" so child processes (Steam + game) definitely see verbose logging as OFF.
        # This is more reliable than just Remove-Item for ensuring normal play is silent.
        $env:AELORIA_ENABLE_VERBOSE_DRAW_LOGS = "0"
        Write-Log "Normal (non-Debug) session: AELORIA_ENABLE_VERBOSE_DRAW_LOGS explicitly set to 0 (verbose draw logs should be suppressed)" "INFO"
    }

    # Auto-deploy newest built DLL into the Development profile (safer than direct to live)
    # We defer AutoDeploy if -BuildFirst is also passed (we want to deploy the *new* build).
    $ShouldAutoDeployNow = $AutoDeployDll -and -not $BuildFirst
    $DeployAfterSuccessfulBuild = $AutoDeployDll -and $BuildFirst

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
            Write-Log "Please install Visual Studio 2019/2022 (with 'MSBuild' workload) or the standalone Build Tools." "ERROR"
            throw "MSBuild.exe not found on this system."
        }

        # When running in DebugMode (-D), force a full Rebuild instead of incremental Build.
        # This guarantees that edits to CONQUER.CPP / DLLInterface.cpp (the main Aeloria files)
        # are always picked up, even if MSBuild's incremental logic thinks the project is up-to-date.
        # Critical for fast iteration during stability / visibility debugging.
        $msbuildArgs = "`"$solutionPath`" /t:RedAlert /p:Configuration=Release /p:Platform=x86 /verbosity:minimal /nologo"
        if ($DebugMode) {
            Write-Log "DebugMode active - forcing full Rebuild of RedAlert project (not incremental)." "INFO"
        }
        Write-Log "Starting MSBuild for RedAlert project..." "INFO"
        Write-Log "Using MSBuild: $msbuildPath" "INFO"
        Write-Log "Command: `"$msbuildPath`" $msbuildArgs" "INFO"

        try {
            $effectiveTarget = if ($DebugMode) { "RedAlert:Rebuild" } else { "RedAlert" }
            $msbuildOutput = & $msbuildPath "$solutionPath" /t:$effectiveTarget /p:Configuration=Release /p:Platform=x86 /verbosity:minimal /nologo 2>&1
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

            # If the user passed both -BuildFirst and -AutoDeployDll, deploy the fresh build now.
            if ($DeployAfterSuccessfulBuild) {
                Write-Log "Build completed successfully - now deploying the new DLL..." "INFO"
                Invoke-AutoDeployDll
            }
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
    if ($DebugMode) {
        $launchArgs += " MOD_DEBUG NO_EVENT_HANDLER"
        Write-Log "Debug flags (MOD_DEBUG) added to launch arguments. (Verbose logging env var was already set for the whole session above.)" "INFO"
    }

    Write-Log "Launching via Steam with arguments: $launchArgs" "INFO"
    Start-Process -FilePath $SteamExe -ArgumentList "-applaunch $AppId $launchArgs"

    # Monitor
    Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::Monitoring)
    Wait-ForGameExit

    # Capture crash report
    Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::CapturingCrash)
    $script:LatestCrashReport = Capture-LatestCrashReport

} catch {
    Write-Log "FATAL ERROR: $_" "ERROR"
    $script:CurrentState = [LauncherState]::Failed
} finally {
    Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::CleaningUp)
    Write-Log "Entering cleanup phase..." "INFO"

    if ($script:SelectedProfile -and (Test-Path $script:SelectedProfile.LivePath)) {
        if ($script:NoCleanup) {
            Write-Log "NoCleanup mode: leaving deployed folder at $($script:SelectedProfile.LivePath)" "INFO"
        } else {
            Remove-Item $script:SelectedProfile.LivePath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Deployed folder removed." "INFO"
        }
    }

    if (-not $script:NoCleanup) {
        Restore-Backup $script:BackupPath $script:SelectedProfile.LivePath
    } else {
        Write-Log "NoCleanup mode: skipping restore of previous backup (keeping fresh deploy)." "INFO"
    }

    if ($script:LatestCrashReport) {
        Write-Log "Latest crash report available at: $($script:LatestCrashReport)" "WARN"
    }

    # In debug mode, always attempt to collect the Aeloria debug log (even on clean exits)
    # so we don't lose diagnostic data on "clean" process exits that are actually stability-related.
    if ($script:DebugShortId) {
        $aeloriaLogPatterns = @(
            "$env:USERPROFILE\Aeloria-Debug-*.log",
            "C:\Users\jacks\Aeloria-Debug-*.log",
            ".\Aeloria-Debug-*.log",
            "$LogDir\Aeloria-Debug-*.log"
        )

        $foundLog = $null
        $launchStartTime = (Get-Item $script:LogFile).CreationTime

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
            try {
                Move-Item -Path $foundLog.FullName -Destination $destPath -Force -ErrorAction Stop
                $script:CollectedAeloriaDebugLog = $destPath
                Write-Log "Collected Aeloria debug log -> $destPath" "INFO"
                Write-Host "Aeloria Debug Log: $destPath" -ForegroundColor Cyan
            } catch {
                Write-Log "WARNING: Failed to collect Aeloria debug log from $($foundLog.FullName)" "WARN"
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
        } else {
            Write-Log "No recent Aeloria debug log found to collect." "DEBUG"
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