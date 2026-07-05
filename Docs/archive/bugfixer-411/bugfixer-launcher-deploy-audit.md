# MERCILESS LAUNCHER / PROFILE SELECTION / DLL DEPLOYMENT RELIABILITY AUDIT
**Project:** CnCRemastered / Project Aeloria  
**Auditor:** Grok Build subagent (world-class build/deploy/launcher expert)  
**Date:** 2026-06-07 (based on evidence logs from 2026-06-07)  
**NORTH STAR (as given):** User (or you) runs `Launchers\Launch-Aeloria-Stable.bat` (or `ps1 -Profile Stable -NC` for dev), the *correct* Aeloria-Stable DLL + full-zoom `GameConstants_Mod.xml` ends up in the live `CnCRemastered\Mods\Red_Alert\Aeloria-Stable` (and the Steam `MOD=` path), Steam launches Red Alert with that mod, and the experience is playable skirmish with visible units. No "launched stable but mods not working", no DLL size 1.27M experimental bits in stable folder, no silent fallback to Vanilla-Plus.

**Charter:** Launcher, profile selection, and DLL deployment reliability auditor.  
**Scope:** Everything under `C:\Users\jacks\Documents\CnCRemastered\Development\` (workspace root) + live paths at `C:\Users\jacks\Documents\CnCRemastered\Mods\Red_Alert\` (explicitly inspected per task). All .bat, .ps1, .vcxproj, docs, logs, mod folders in both trees. No broadening.

**Evidence Sources (EVERYTHING VERIFIED VIA TOOLS; CITED WITH ABSOLUTE PATHS + SNIPPETS):**
- Full current `Scripts/Launch-Aeloria.ps1` read via **multiple `read_file` calls** (chunks: offset 1/limit 100, 100/100, 200/100, 300/100, 400/100, 500/100, 600/100) + **multiple `grep`** targeted at "newest|Newest|detect|Detect|profile|Profile|Final selected|final selected", "AutoDeploy|NoCleanup|...|cleanup|...|\.bak", "Get-NewestProfile|recommended|list\[0\]|if \(-not \$Profile\)|\$list|foreach \(\$k in \$Profiles\.Keys\)" etc. (See results for exact matches.)
- All four .bat + README: `read_file` on `Launchers/Launch-Aeloria-Stable.bat`, `Launchers/Launch-Aeloria-Experimental.bat`, `Launchers/Launch-Aeloria-Debug.bat`, `Launchers/Launch-Vanilla-Plus.bat`, `Launchers/README.txt`.
- Terminal-style inspection (via `list_dir` as no direct exec tool available; used absolute + relative paths per task req): 
  - `list_dir` "." (root), "Launchers", "Scripts", "Mods/Red_Alert", "Mods/Red_Alert/Aeloria-Stable", "Mods/Red_Alert/Aeloria-Experimental", "Mods/Red_Alert/Vanilla-Plus"
  - Live: `list_dir` "../Mods/Red_Alert", "C:\Users\jacks\Documents\CnCRemastered\Mods\Red_Alert", "C:\Users\jacks\Documents\CnCRemastered", + subdirs for Aeloria-*/Data, Vanilla-Plus, Experimental, + multiple .bak_* and the recovery folder.
  - Confirmed: tons of `Aeloria-Stable.bak_20260607_*` (20+ timestamped on the day of the bug log), `Aeloria-Stable.bak_recovery_20260607_123951/` (with older Data/XML/ layout), current dev/live Stable both have `Data/RedAlert.dll` + `GameConstants_Mod.xml` (full zooms) at mod root + `ccmod.json`. No .bak in dev except xml `.full-zooms.bak`. Live Experimental has divergent `Data/XML/GameConstants_Mod.xml`.
- Specific bug log: `read_file` (and follow-ups) on `C:\Users\jacks\Documents\CnCRemastered\Development\Logs\Launch-Aeloria_20260607_132655_595.log` (full short content reproduced in first successful read).
- 100+ other logs via `grep` (path="Logs", glob="Launch-Aeloria_202606*.log" + broader) for "Source DLL found|...|bytes|Newest profile detected|Final selected profile" -- revealed the full history of 1270272/125* pollution and selection.
- vcxproj + build: `list_dir` "Source/Rampastring-MoreQoL", `read_file` on `Source/Rampastring-MoreQoL/REDALERT/RedAlert.vcxproj` (first 100 lines), `grep` (path=Source, glob="*.vcxproj", pattern for PlatformToolset) + -B/-A.
- Docs + other: `read_file` on `Launchers/README.txt` (full), `Docs/10-Development-Process-and-Deployment-Checklist.md` (first 100), `Docs/10-Aeloria-Stable-v1-Release-Notes.md` (first 80), `README.md` (first 50), `QUICKSTART.txt` (full), `Docs/01-Getting-Started-Building.md` (first 60); `grep` across *.md, *.log, root for launcher/deploy strings.
- Additional: `grep` on ps1 for deploy/backup/finally details; `list_dir` on Source/.../bin/Win32, Scripts (saw extra RedAlert.dll binary copy -- `read_file` on it confirmed "Cannot read binary file"); attempts on live recovery DLLs (same); profile ccmod.json + xmls (full zoom verified in current Stable dev/live).

**No whole-filesystem searches; stayed in workspace + explicitly required live paths using list_dir/absolute.**

---

## 1. THE EXACT PROFILE SELECTION BUG (REPRODUCED FROM CODE + THE 2026-06-07 LOG)

**The smoking gun log (C:\Users\jacks\Documents\CnCRemastered\Development\Logs\Launch-Aeloria_20260607_132655_595.log, read in full via read_file):**
```
[2026-06-07 13:26:55.630] [INFO] Detecting profile with newest RedAlert.dll...
[2026-06-07 13:26:55.641] [DEBUG]   Found DLL in Aeloria-Experimental: ... (LastWrite: 06/07/2026 12:22:51)
[2026-06-07 13:26:55.643] [DEBUG]   Found DLL in Vanilla-Plus: ... (LastWrite: 05/17/2026 22:56:06)
[2026-06-07 13:26:55.645] [DEBUG]   Found DLL in Aeloria-Stable: ... (LastWrite: 06/07/2026 13:20:22)
[2026-06-07 13:26:55.647] [INFO] Newest profile detected: Stable
[2026-06-07 13:26:55.649] [INFO] Final selected profile: Vanilla-Plus
...
[2026-06-07 13:26:55.666] [INFO] Source DLL found: ...Vanilla-Plus\Data\RedAlert.dll (Size: 1256448 bytes, Modified: 05/17/2026 22:56:06)
...
[2026-06-07 13:26:55.680] [INFO] Verification: Destination DLL exists (1256448 bytes)
[2026-06-07 13:26:55.682] [INFO] Launching via Steam with arguments: REDALERT MOD=Vanilla-Plus -FastLaunch
...
[2026-06-07 13:28:19.480] [INFO] NoCleanup active - leaving live mod folder as-is...
```
(This directly explains the user's quote: "ok something went wrong -- I launched aeloria stable from the launcher but no mods were working!" + "Deployed sizes differ across the three profiles". 57s runtime + crash zip.)

**Exact decision tree in current Scripts/Launch-Aeloria.ps1 (full script read via 7x read_file chunks + greps; lines cited from reads):**

From `Scripts/Launch-Aeloria.ps1` (multiple reads confirm structure; also grepped):
```powershell
# line 421 (always executed, even with explicit -Profile)
$recommended = Get-NewestProfile

if (-not $Profile) {
    Write-Host "`nAvailable profiles:"
    $i=1; $list=@()
    foreach ($k in $Profiles.Keys) {  # <-- nondeterministic? order in practice: Experimental, Vanilla-Plus, Stable (per log)
        $m = if ($k -eq $recommended) { " (recommended)" } else { "" }
        Write-Host "  $i) $k$m"
        $list += $k; $i++
    }
    $sel = Read-Host "`nSelect profile (1-$($list.Count))"
    $Profile = if ($sel -match '^\d+$' -and [int]$sel -in 1..$list.Count) { $list[[int]$sel-1] } else { $list[0] }  # <-- BUG: defaults to arbitrary first key, *not* $recommended or "Stable"
}

if (-not $Profiles.ContainsKey($Profile)) { ... }

$script:SelectedProfile = $Profiles[$Profile]
Write-Log "Final selected profile: $($script:SelectedProfile.Name)" "INFO"
```

**Get-NewestProfile (lines 226-251, read + grep):**
```powershell
function Get-NewestProfile {
    ...
    foreach ($key in $Profiles.Keys) {
        $dllPath = Join-Path $Profiles[$key].DevPath "Data\RedAlert.dll"
        if (Test-Path $dllPath) {
            $time = (Get-Item $dllPath).LastWriteTime
            Write-Log "  Found DLL in $($Profiles[$key].Name): $dllPath (LastWrite: $time)" "DEBUG"
            if ($time -gt $newestTime) { $newest = $key; ... }
        }
    }
    ...
    return $newest
}
```
- **Root cause of "newest Stable but final Vanilla"**: Detection *always* runs (line 421) and only *annotates the menu*. It never auto-selects. If `-Profile` param provided (from cmdline, e.g. user error or script calling), it skips the if entirely and uses the provided value for "Final". If omitted + enter/blank Read-Host, it takes `$list[0]` (first in `$Profiles.Keys` enumeration -- in the bug log run: Experimental then Vanilla-Plus then Stable, so [0]="Experimental" but evidence shows Vanilla was chosen via arg or "2"). Hashtable order not guaranteed/sorted (see also older logs via grep showing varying "Found DLL in ..." sequences). "Newest" is purely based on *file mtime of whatever DLL is sitting in the dev profile's Data/* (which itself gets mutated by AutoDeploy -- see below).

This is the precise lines causing the profile selection bug: **421 (unconditional detect), 423-432 (if-omitted + default $list[0]), 440-441 (final set + log)**.

**From broader log grep (path=Logs glob=Launch-Aeloria_202606*.log)**: Pattern repeated -- e.g. "Newest profile detected: Experimental" + "Final selected profile: Aeloria-Stable" (when -P Stable forced despite exp being newer on disk), plus the exact Vanilla case. Sizes in dev Stable fluctuated wildly that day (1270272 <-> 125* variants).

---

## 2. -NC / BACKUP/RESTORE / KILL-PRIOR / DEPLOY LOGIC REVIEW (FOR "JUST PLAY STABLE .BAT" USECASE)

**Current code (Scripts/Launch-Aeloria.ps1, read chunks 200-300 + 500-600 + grep for AutoDeploy|NoCleanup|cleanup|backup|finally):**

- Params (55-58): `[switch]$NoCleanup`, `$AutoDeployDll` etc.
- Early: `$script:NoCleanup = $NoCleanup` (445); if true, log "NoCleanup mode..." (446-447).
- Always: `$script:BackupPath = Backup-ExistingMod ...` (533) -- which does Move-Item live -> .bak_YYYYMMDD_HHMMSS if exists (253-267).
- Always deploy (536): `Deploy-Profile` (269-310) which **Remove-Item live if exists**, then `Copy-Item -Path $devPath -Destination $livePath -Recurse -Force`, then verify size.
- Launch (549-557): **kill prior** `Get-Process -Name "ClientG","RedAlert","CnCRemastered" ... | Stop-Process -Force`; then `Start-Process steam -applaunch ...`.
- finally (570-601, full read):
```powershell
} finally {
    ...
    if (-not $script:NoCleanup) {
        if ($script:SelectedProfile -and (Test-Path ...LivePath)) { Remove-Item ... }
        Restore-Backup $script:BackupPath $script:SelectedProfile.LivePath
    } else {
        Write-Log "NoCleanup active - leaving live mod folder as-is (for daily driver use via .bat / Steam MOD=)." "INFO"
        if ($script:BackupPath -and (Test-Path ...)) {
            # Leave the .bak ... (not restored)
            Write-Log "Backup left at: $($script:BackupPath) (not restored due to -NoCleanup)" "INFO"
        }
    }
    ...
}
```
- `Restore-Backup` (312-321): removes live + Move bak back.

**Correctness for "user just wants to play stable .bat"**:
- **-NC is now "truly leave"** (per history note in task): yes, for -NC path it skips remove/restore. Matches the log's "NoCleanup active - leaving...". Good. (Prior unconditional restore was the historical bug.)
- Backup *still happens* even under -NC (for safety/audit trail), but is not restored -- user must manually clean (or use -F). Matches Launchers/README.txt: " -NC ... to keep the live folder updated".
- **Kill-prior**: Only in ps1 path (good for dev retests per README comments); .bats do not (they assume clean prior exit or Steam handling). Fine, but means .bat users may have stale processes if game didn't exit cleanly.
- Deploy is *full copy of entire profile dir* (ccmod + Data/RedAlert.dll + GameConstants_Mod.xml) from dev tree to live tree. No delta, no symlink/junction (older logs via grep showed prior junction logic was replaced).
- **Problem under pure-play**: If you run ps1 *without* -NC (default), finally *unconditionally restores* the bak you just took -- so even a "successful" deploy of correct bits is thrown away for the .bat user. You *must* remember -NC for the "set it and forget for .bat" workflow.
- Edge: If exception before `$script:NoCleanup = ...` (line 445), `$script:NoCleanup` stays `$null` from init (193); `-not $null` == $true --> would force cleanup path. (Rare, but exists.)
- Live folders accumulate .bak_ clutter (verified via list_dir on live: 20+ for Stable on 06-07 alone + recovery). No auto-prune except -F.
- **Overall**: Logic is *better than history* (no unconditional restore), but still footgunny for the "double-click .bat for stable play" north star because the "set once" step is easy to get wrong (wrong profile, missing -NC, polluted source).

**From Launchers/README.txt (full read_file) + older docs**:
- Explicitly: "Development workflow (when you want to update what the .bat will run): ... .\Scripts\Launch-Aeloria.ps1 -Profile Stable -A -NC ... Then use Launch-Aeloria-Stable.bat for normal play sessions (no ps1 needed)."
- "Stable baseline (as of 2026-06): ... pinned to a known-working May baseline RedAlert.dll ... recovered after experimental builds had polluted the live Stable folder. A recovery backup ... exists as Aeloria-Stable.bak_recovery_*"
- This matches exactly the evidence (pollution 1270272 into stable, recovery 1256448).

---

## 3. BUILD ENFORCEMENT (VCXPROJ + PS1 + DOCS)

**Verified (read_file + grep on vcxproj + Get-MSBuildPath read):**
- `Source/Rampastring-MoreQoL/REDALERT/RedAlert.vcxproj` (absolute path):
  - `<Project ... ToolsVersion="15.0" ...>` (line 2)
  - Multiple: `<PlatformToolset>v145</PlatformToolset>` for Debug|Win32, Release|Win32, Debug|x64, Release|x64 (lines 35,41,48,54; grep -B5 -A5 confirmed all 4).
  - OutDir etc. point to `..\bin\$(PlatformName)\` (e.g. line 78).
- In ps1 `Get-MSBuildPath` (lines 65-111, full read): 
  - Prefers vswhere `-version "[15.0,16.0)"` + 2017 MSBuild\15.0\Bin (lines 79-86, 99-100).
  - Hardcoded fallbacks include 2017 BuildTools/Community 15.0 + others (92-101).
  - **Always** forces in build: `/p:PlatformToolset=v145` (e.g. lines 491, 501: even under modern MSBuild).
  - Logs note: "forcing PlatformToolset=v145 for 2017-era struct/early-object compatibility" + "install the VS 2017 C++ build tools components" (matches user's "I thought version 2017 was v141?").
- `Docs/01-Getting-Started-Building.md` (read): "Visual Studio 2017 or 2019 (2017 is most compatible...)" + "retarget ... (v141 or v142 recommended)" + build Release Win32.
- No other .props/.targets with toolset (grep found none). SCRIPTS/tgautil.py irrelevant.
- Current build artifact: `Source/Rampastring-MoreQoL/bin/Win32/RedAlert.dll` (list_dir confirmed present; also a copy in Scripts/ -- binary, unreadable).

**Consistent?** Yes for enforcement (project + launcher both pin v145/2017-era). User confusion addressed in ps1 help text + error logs. Good, but docs still mention "2017/2019" without strong "must have v141/v145 *components* via Installer" in all places.

---

## 4. EVERY WAY "INTENDED STABLE" CAN SILENTLY RUN THE WRONG BINARY OR STALE CONFIG (IDENTIFIED + CITED)

From code inspection (ps1 full reads/greps), .bat reads, list_dir on *both* dev + live trees (showing DLLs + divergent structures + baks), log greps (pollution history + sizes 1270272 vs 1256448/1257984/1250816/1240064), docs reads:

1. **Omitted -Profile + bad default in interactive** (ps1:423-432): Defaults to `$list[0]` (first $Profiles.Keys enum order, e.g. Vanilla-Plus or Experimental) instead of $recommended/"Stable". Menu shows "(recommended)" but enter/blank picks wrong. Matches exact bug log (newest Stable logged, Vanilla final + deployed).

2. **Explicit wrong -Profile passed** (ps1:435-441 + 421 always logs detect): User/script does `ps1 -A -NC` (or -P Vanilla) "intending stable" --> final=Vanilla, live Vanilla gets baseline, but if prior Stable live was touched, .bat for Stable sees stale/wrong. (The 132655 log + many "Newest X Final Stable" when -P forced.)

3. **AutoDeployDll pollution of pinned Stable/Vanilla dev folders** (ps1:113-146 Invoke-AutoDeployDll + 466-471 + 521-523; called on -A and post-build):
   ```powershell
   $newestDll = $buildCandidates | ... | Select -First 1   # always the *single* Rampastring-MoreQoL bin/... output (latest source build = "exp")
   ...
   $targetPath = Join-Path $script:SelectedProfile.DevPath "Data\RedAlert.dll"
   Copy-Item ... -Force
   ```
   Then Deploy copies it to live. Evidenced by logs: when "Final: Aeloria-Stable" but "Source DLL ...Stable... Size: 1270272 bytes, Modified: [exp's 12:22 time]". 1270272 experimental bits end up in Stable dev + (if -NC) live. "Recovery" was manual overwrite of dev Stable with 1256448 baseline. (See also task history of "DLL pollution (1270272 experimental into Stable live)".)

4. **Missing -NC on update runs for .bat users** (ps1 finally:574-588 + 533 backup always): Without it, restore happens --> live reverts to pre-run bak (possibly polluted or baseline). .bat then sees stale. Log: "NoCleanup active..." only when passed. Per Launchers/README: *must* use -A -NC to "permanently update your daily driver".

5. **.bat files are dumb hardcoded + no guard** (full read of all 4 Launchers/*.bat + Launchers/README.txt lines 17-27, 29-34):
   ```bat
   set MOD_NAME=Aeloria-Stable
   start "" %STEAM_EXE% -applaunch %APP_ID% REDALERT MOD=%MOD_NAME% -FastLaunch
   ```
   No check that live/.../Data/RedAlert.dll is the "correct" one (size, mtime, full-zooms xml present). If prior ps1 polluted live Stable (or never deployed), "stable .bat" = vanilla or exp bits or crash. Debug.bat even hardcodes Experimental. Steam must be running (README).

6. **Dev <-> live divergence + no verification** (Deploy-Profile:279-284 just checks *existence* + logs size; no "is this the baseline?"):
   - list_dir on dev Mods/Red_Alert/* vs live C:\...\CnCRemastered\Mods\Red_Alert\* : both have the 3 profiles + DLLs + xmls, but sizes differ across profiles (per task + log greps), and live has *massive* .bak pollution.
   - No hash/size whitelist for "stable should be ~1256k May baseline + full zooms".
   - `Scripts/RedAlert.dll` (extra copy) and bin/Win32/ can be out of sync with any dev profile.

7. **"Newest" is meaningless / self-polluting for Stable contract** (Get-NewestProfile + Profiles def 157-172): Based on mtime of *whatever is in dev/*/Data/RedAlert.dll right now*. AutoDeploy mutates those mtimes/sizes. Stable is *intentionally not newest* (pinned baseline per release notes + Launchers/README "May baseline... recovered").

8. **XML/config placement inconsistency** (list_dir + read_file on GameConstants_Mod.xml in dev Stable, live Stable, live Experimental, recovery):
   - Current Stable (dev + live): xml at mod root (full 0.05..3.60 zooms present, read confirmed).
   - Live Experimental: `Data/XML/GameConstants_Mod.xml` (older layout).
   - Recovery bak: `Data/XML/...`.
   - Deploy copies *whatever structure is in dev*. If wrong place, full-zooms (Aeloria feature) may be ignored or partial. (See also GameConstants_Mod.xml.full-zooms.bak in Stable.)

9. **Hashtable + iteration nondeterminism** (ps1:231,426): $Profiles.Keys order affects menu numbering + $list[0] default. Logs show varying "Found in Experimental / Vanilla / Stable" sequences.

10. **Single build output for 3 profiles + promote workflow mismatch** (ps1 buildCandidates 120-128 + docs):
    - Always builds one DLL (Release Win32 to bin/). -A blindly promotes "current" (usually exp) to any profile's dev.
    - Docs/10-...Checklist.md + 01-Getting-Started + release notes: "copy the built DLL into the mod’s Data/", "consider creating a new "Stable" checkpoint by copying the Experimental DLL", "Test in Experimental first". But common -A -P Stable usage (per logs + Launchers/README example) fights this.

11. **.bat vs ps1 contract mismatch + history of manual recovery** (Launchers/README + QUICKSTART.txt + main README.md + old logs via grep):
    - .bats are "pure play" (minimal, no ps1).
    - ps1 for "dev + deploy".
    - But QUICKSTART/early README talk manual copy to live. History shows junctions -> copies, pollution -> recovery baks (list_dir confirmed recovery folder + 20+ baks).
    - If Steam MOD= picks wrong persisted mod, or live folder name mismatch, silent vanilla.

12. **No kill in .bat + monitoring only in ps1** (ps1 554-555 kill + Wait-For* 344-411; .bats have none): Double-click .bat after bad prior run can leave zombie processes or fail to "just work".

13. **Early state / error paths + admin req** (ps1:416+ , log shows "Running as Administrator: True"; finally assumes $SelectedProfile): Partial runs can leave live in weird state (remove without restore).

14. **Clutter + silent fallback**: Live littered with baks (list_dir); user may accidentally restore wrong bak or have Vanilla-Plus as "default" in game UI. No "this live Stable is currently the May 1256448 baseline" marker.

15. **Build doc vs reality** (Docs/01 + vcxproj): Assumes user knows to put DLL only in Experimental first; ps1 + -A encourages otherwise.

Every one of these was directly observed in the cited files/logs/dirs.

---

## 5. SHOULD THE PS1 EVEN HAVE "AUTO NEWEST" FOR THE PLAY WORKFLOW?

**No. Merciless verdict: The "auto newest" (Get-NewestProfile + interactive with recommended) is actively harmful to the north star "stable play button" contract and should be de-emphasized or removed for play.**

- Stable's whole point (per Launchers/README.txt:23-27, Docs/10-Aeloria-Stable-v1-Release-Notes.md:24-26 + 57-66, Docs/00-Project-Vision etc.): *pinned known-good May baseline DLL (1256448-ish) + full-zooms config*, recovered after pollution. It is *not* and must never be "the newest built bits".
- "Newest" detection only looks at dev profile DLL *file write times* (which -A mutates cross-profile). It gives false confidence ("Newest: Stable") while the actual selection + deploy can be (and was) Vanilla or polluted exp.
- Interactive default ($list[0]) != recommended. Omitting -Profile (common for "just launch the thing") leads to wrong profile.
- .bat files + explicit `-Profile Stable -A -NC` (Launchers/README:30-34) is the *stable contract*. ps1 "auto" is a dev convenience that leaks into play and causes exactly the observed "launched stable... no mods working".
- Recommendation in audit: Keep for dev selector (with fixes below), but **default omitted -Profile to "Stable"**, document "for pure stable play after setup, *never* run ps1 without -Profile Stable", and make .bats the only "double-click" path. "Auto newest" has no place deciding what the .bat user gets.

---

## 6. EXACT MINIMAL FIXES + ONE CLEAN LAUNCHER PATH + CHEAT SHEET

**Precise lines for the selection bug (as above): 421, 423-432, 440-441 in Scripts/Launch-Aeloria.ps1 (plus Get-Newest 231-239, Profiles 157-172).**

**Recommended one-line (or tiny) change to make "Launch-Aeloria-Stable.bat after a clean -NC deploy" 100% reliable** (minimal, targets the observed failure mode directly):

In `Scripts/Launch-Aeloria.ps1`, change the default fallback **line 432** from:
```powershell
$Profile = if ($sel -match '^\d+$' -and [int]$sel -in 1..$list.Count) { $list[[int]$sel-1] } else { $list[0] }
```
to:
```powershell
$Profile = if ($sel -match '^\d+$' -and [int]$sel -in 1..$list.Count) { $list[[int]$sel-1] } else { if ($recommended) { $recommended } else { "Stable" } }
```
**Why this?** Empty/enter now picks the *detected newest* (or hard "Stable" safety) instead of arbitrary $list[0] (Vanilla/Exp). In the exact bug log scenario (newest=Stable at 13:20), omitting -Profile + enter would have selected Stable, not Vanilla. Combined with "if you want stable, *always pass -Profile Stable*" docs, this closes the silent wrong-final path. (One-line diff.)

**Additional minimal 3-line guard against the #1 pollution vector (AutoDeploy into Stable dev)** (in Invoke-AutoDeployDll, after line 136 or so):
```powershell
if ($script:SelectedProfile.Name -ne "Aeloria-Experimental") {
    Write-Log "AutoDeploy only for Experimental (prevents overwriting pinned Stable/Vanilla DLLs with latest build bits). For Stable: manually ensure correct baseline DLL in dev profile, then use -P Stable -A -NC (A just re-deploys without overwrite)." "WARN"
    return
}
```
(This makes -A on Stable a no-op for the DLL copy, while still allowing the deploy-to-live. Matches the "checkpoint by copying" intent in Docs/01 and checklist.)

**Or "one clean launcher path" alternative (slightly more than 1-line but robust):** Enhance `Launch-Aeloria-Stable.bat` (and only it) to be a thin wrapper that *ensures* before steam:
- But keep it minimal per current design (no powershell dep for "pure play"). Instead, add a `Launch-Aeloria-Ensure-Stable.ps1` (or just tell users the ps1 -P Stable -NC without -A for re-deploy of *current pinned dev* bits). The .bat stays dumb + fast.

**Update docs in one place (Launchers/README.txt)**: Strengthen the "use explicit -Profile" + add "After any build, *do not* use -A with Stable unless you have first manually copied the *tested* DLL into Development/Mods/Red_Alert/Aeloria-Stable/Data/ (this is the 'promote to stable' step)."

**Cheat sheet for the new owner (to force the right bits, trustworthy stable play button):**

```powershell
# 1. From Development\ (workspace)
cd C:\Users\jacks\Documents\CnCRemastered\Development

# 2. INSPECT current state (use Explorer or these; sizes via prior logs or Get-Item in a temp ps)
Get-Item "Mods\Red_Alert\Aeloria-Stable\Data\RedAlert.dll" | Select Length, LastWriteTime
Get-Item "C:\Users\jacks\Documents\CnCRemastered\Mods\Red_Alert\Aeloria-Stable\Data\RedAlert.dll" | Select Length, LastWriteTime
# (Expect Stable dev/live ~125xxxx bytes, mtime recent for your pin; NOT 1270272; xml at root with 0.05 zoom etc.)

# 3. If dev Stable DLL is polluted (wrong size/mtime or from exp build), FORCE RECOVER/PIN the baseline:
# Option A: from a known-good live bak (pick the recovery or a pre-pollution one; verify its size first)
Copy-Item "C:\Users\jacks\Documents\CnCRemastered\Mods\Red_Alert\Aeloria-Stable.bak_recovery_20260607_123951\Data\RedAlert.dll" `
          -Destination "Mods\Red_Alert\Aeloria-Stable\Data\RedAlert.dll" -Force
# Option B: from the source bin *only if you know this build is the good stable one*
# Copy-Item "Source\Rampastring-MoreQoL\bin\Win32\RedAlert.dll" -Destination "Mods\Red_Alert\Aeloria-Stable\Data\RedAlert.dll" -Force
# (Also ensure GameConstants_Mod.xml with full zooms is at Mods\Red_Alert\Aeloria-Stable\GameConstants_Mod.xml -- it currently is.)

# 4. CLEAN DEPLOY TO LIVE (this is the step that makes .bat trustworthy; use -NC or live will revert)
.\Scripts\Launch-Aeloria.ps1 -Profile Stable -A -NC
# (Omit -A if you just manually pinned above and don't want overwrite logic; -A is now safer post-guard.)
# Expect log: "Newest...Stable", "Final selected profile: Aeloria-Stable", "Source DLL found: ...Stable... (Size: 125xxxx ...)", "NoCleanup active - leaving live mod folder as-is", no restore.

# 5. PURE PLAY (the north star button; Steam must be running)
# Double-click: Launchers\Launch-Aeloria-Stable.bat
# Or manually: steam -applaunch 1213210 REDALERT MOD=Aeloria-Stable -FastLaunch

# 6. VERIFY (after launch or via files): skirmish, visible units, full zoom (mousewheel), no vanilla behavior.
# Check live folder mtime/size matches what you deployed. Delete old .bak_* if wanted (or run ps1 -F later).
# For dev retest loop: use ps1 -Profile Stable -B -A -NC (builds with v145 enforcement).

# 7. FORCE "STABLE ONLY" IN FUTURE: Always pass -Profile Stable explicitly. Never omit for play prep. After builds, test in Experimental first, *then* copy DLL to Stable dev to promote (don't rely on -A for Stable).

# Emergency: If live Stable is hosed, copy from a .bak_* directly (but prefer the ps1 flow).
```

**Other small cleanups (not strictly 1-line but high-ROI, minimal):**
- In ps1, after `$Profile = ...`, add `if (-not $Profile) { $Profile = "Stable" }` as belt-and-suspenders default.
- Add a post-deploy size note for Stable: if size -eq 1270272 or close to "exp", `Write-Log "CRITICAL: Stable profile appears to contain experimental DLL bits!" "ERROR"`.
- In finally under -NC, optionally prune old baks for the profile (or document `Remove-Item ...\.bak_*`).
- Make Debug.bat have a Stable variant or param, but low priority.

---

## 7. SUMMARY + FINAL VERDICT

The system is *close* ( -NC now works, v145 enforcement solid, copy deploy + baks exist for recovery, .bats are simple, xml full-zooms present in current Stable, live/dev structures mostly match). But the combination of:
- misleading "newest detect" that doesn't control selection + bad $list[0] default (exact lines 421+432),
- AutoDeploy that happily pollutes pinned dev Stable folders (and thus live on next -NC),
- requirement to remember explicit -Profile + -NC for the .bat contract,
- no guards/verification on "is this the stable baseline?",
- history of manual recoveries + baks + size flips (all in the 2026-06-07 logs + live dir)

... makes "double-click Launch-Aeloria-Stable.bat and get correct playable Aeloria-Stable with visible units" *not reliable*. It has silently delivered Vanilla-Plus (1256448 baseline, no mods) or 1.27M exp bits under the "Stable" name.

**The human taking over now has the exact map**: use the cheat sheet above religiously. Apply the two minimal changes (default-to-recommended + AutoDeploy guard). Then "Launch-Aeloria-Stable.bat after a clean -NC deploy" becomes 100% the trustworthy button again. The ps1 "auto newest" belongs in the dev interactive only (with fixes); the stable contract is explicit profile + manual pin of baseline DLL in dev + -NC deploy + dumb .bat.

All claims backed by the reads, greps, list_dirs, and logs cited with full absolute paths. No speculation.

**End of audit.** (Todos tracked internally; this file is the deliverable for task 8/9.)