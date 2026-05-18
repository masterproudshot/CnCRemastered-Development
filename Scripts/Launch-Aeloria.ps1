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
                        appear in Aeloria_Debug.log (the "debugmode flag flips the loggins switch on").
  -B, -BuildFirst       Build the RedAlert project using MSBuild before deploying the DLL.
                        Auto-detects MSBuild.exe (prefers vswhere, falls back to common VS 2019/2022 paths).
                        Only activates if explicitly passed on the command line (no interactive prompt).
  -A, -AutoDeployDll    Auto-copy the newest built RedAlert.dll from Visual Studio
                        into the profile's Development folder.
                        When used together with -DebugMode it will also search Debug build folders
                        and the verbose logging env var will be active for the whole session.
  -F, -ForceCleanup     Force cleanup of backup and temp folders.
  -h, -?                Show this help.

Profiles:
  Experimental        - Latest changes, may be unstable. Use for active development.
  Stable              - Recommended for normal play. Good balance of features and stability.
  Vanilla-Plus        - Minimal changes, closest to vanilla with light QoL.

Note: After editing function.h / wwstd.h / packing headers, always Clean + Rebuild in Visual Studio.
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
    [switch]$AutoDeployDll
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

    $script:LogFile = Join-Path $LogDir "Launch-Aeloria_$(Get-Date -Format 'yyyyMMdd_HHmmss_fff').log"
    Write-Log "=== Project Aeloria Launcher Started ===" "INFO"
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"
    Write-Log "Running as Administrator: $([bool]([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))" "INFO"
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
    $checkInterval = 3
    $elapsed = 0
    $minimumRuntime = 45    # Don't allow cleanup until game has been visibly running for at least 45 seconds

    while ($elapsed -lt $timeoutSeconds) {
        $running = Get-Process -Name $processes -ErrorAction SilentlyContinue

        if (-not $running) {
            if ($elapsed -ge $minimumRuntime) {
                Write-Log "Game processes have exited after visible runtime of $elapsed seconds." "INFO"
                return
            } else {
                Write-Log "Processes disappeared too early ($elapsed sec). Waiting to confirm..." "DEBUG"
                Start-Sleep -Seconds 5
                $elapsed += 5
                continue
            }
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

    # Debug mode decision + env var setup - do this *very early* (right after profile)
    # so that -AutoDeployDll, -BuildFirst, and every later step can react to it.
    # Note: We no longer prompt interactively. Pass -DebugMode (or -D) explicitly if desired.

    if ($DebugMode) {
        $env:AELORIA_ENABLE_VERBOSE_DRAW_LOGS = "1"
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

        $msbuildArgs = "`"$solutionPath`" /t:RedAlert /p:Configuration=Release /p:Platform=x86 /verbosity:minimal /nologo"
        Write-Log "Starting MSBuild for RedAlert project..." "INFO"
        Write-Log "Using MSBuild: $msbuildPath" "INFO"
        Write-Log "Command: `"$msbuildPath`" $msbuildArgs" "INFO"

        try {
            $msbuildOutput = & $msbuildPath "$solutionPath" /t:RedAlert /p:Configuration=Release /p:Platform=x86 /verbosity:minimal /nologo 2>&1
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
    Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::BackingUp)
    $script:BackupPath = Backup-ExistingMod $script:SelectedProfile.LivePath

    Set-Variable -Name CurrentState -Scope Script -Value ([LauncherState]::Deploying)
    Deploy-Profile $script:SelectedProfile.DevPath $script:SelectedProfile.LivePath

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
        Remove-Item $script:SelectedProfile.LivePath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Deployed folder removed." "INFO"
    }

    Restore-Backup $script:BackupPath $script:SelectedProfile.LivePath

    if ($script:LatestCrashReport) {
        Write-Log "Latest crash report available at: $($script:LatestCrashReport)" "WARN"
    }

    Write-Log "=== FINAL STATE: $($script:CurrentState) ===" "INFO"
    Write-Host "`n=== LAUNCHER SESSION SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Log file: $($script:LogFile)" -ForegroundColor White
    if ($script:LatestCrashReport) {
        Write-Host "Crash report: $($script:LatestCrashReport)" -ForegroundColor Yellow
    }
    Write-Host "State: $($script:CurrentState)" -ForegroundColor Green
}