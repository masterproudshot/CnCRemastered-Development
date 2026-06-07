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
    [switch]$AutoDeployDll,

    [Alias("NC")]
    [switch]$NoCleanup
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

    # NoCleanup / NC: when set, we deploy (if -A) but leave the live mod folder in place after the session
    # so that Launch-Aeloria-Stable.bat (or Steam MOD=) will continue to use the updated bits for normal play.
    $script:NoCleanup = $NoCleanup
    if ($script:NoCleanup) {
        Write-Log "NoCleanup mode: deployed mod will be left in the live location (no restore at end)." "INFO"
    }

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
            Write-Log "Please install Visual Studio (with MSBuild workload) or the standalone Build Tools." "ERROR"
            Write-Log "For best compatibility with early object creation and custom 4p skirmish (struct layout, vtable, RTTI), install the VS 2017 C++ build tools components:" "ERROR"
            Write-Log "  Visual Studio Installer -> Modify your VS 18/2022 -> Individual components -> search 'v141' or '2017' -> 'MSVC v141 - VS 2017 C++ x86/x64 build tools'." "ERROR"
            throw "MSBuild.exe not found on this system."
        }

        # Always force PlatformToolset=v145 (2017-era) for struct packing / ODR / early-RTTI-object compatibility.
        # The .vcxproj specifies it, but we pass explicitly to guarantee the right compiler/linker even under newer VS.
        $msbuildArgs = "`"$solutionPath`" /t:RedAlert /p:Configuration=Release /p:Platform=x86 /p:PlatformToolset=v145 /verbosity:minimal /nologo"
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

    if (-not $script:NoCleanup) {
        if ($script:SelectedProfile -and (Test-Path $script:SelectedProfile.LivePath)) {
            Remove-Item $script:SelectedProfile.LivePath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Deployed folder removed." "INFO"
        }

        Restore-Backup $script:BackupPath $script:SelectedProfile.LivePath
    } else {
        Write-Log "NoCleanup active - leaving live mod folder as-is (for daily driver use via .bat / Steam MOD=)." "INFO"
        # Still clean a backup we took if present (user can ForceCleanup separately if they want it gone)
        if ($script:BackupPath -and (Test-Path $script:BackupPath)) {
            # Leave the .bak for safety, but do not restore it. User can manually delete later.
            Write-Log "Backup left at: $($script:BackupPath) (not restored due to -NoCleanup)" "INFO"
        }
    }

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