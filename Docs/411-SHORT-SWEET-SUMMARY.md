# 411-SHORT-SWEET-SUMMARY.md

> **Historical snapshot (2026-06-07).** For current project state, read **`Docs/AELORIA-STATUS-20260620.md`** and **`SESSION-HANDOFF.md`** first. This doc captures the original visibility/guard crisis investigation; much has changed since (bulk registration, 5z-n/n2 fixes, soak analyzer).

**Executive Briefing for New Project Owner**  
**Synthesized from:** Docs/AELORIA-BUGFIXER-TEAM-411-LOWDOWN.md (master + post-specialist addendum) + bugfixer-draw-pipeline-report.md + bugfixer-lifecycle-report.md + bugfixer-git-history-411.md + bugfixer-launcher-deploy-audit.md + HANDOFF-TO-NEW-OWNER-20260607.txt  
**Date:** 2026-06-07  
**All claims directly from reports (exact SHAs, file:line, log excerpts). No source re-investigation.**

## 1-2 Sentence Overall Problem
Map/terrain loads in custom 4p skirmish (via .bat or ps1), but starting units (infantry esp. + vehicles, player + AI) are invisible / unselectable / unorderable; session often crashes after 30-60s (or user kills it). Even "vanilla" baselines exhibit it; launcher sometimes deploys wrong profile; "double-click Launch-Aeloria-Stable.bat just works" contract is broken. North star (visible/selectable units + stable minutes + full-zoom mods + no crash) not met.

## Current Branch + Submodule Reality
- **Most "stable" (least-broken for "loads without immediate crash")**: `stable` branch at outer **6cd627acebd6d75d001859bbbc2da551ed9c634c** ("stable: pin submodule to milestone commit 3e53e4c ... first non-crashing skirmish load baseline"); submodule on-disk exactly **3e53e4cb31b9c5ac99c2c76aa76bb893bc7ff275** (the "packing hygiene + granular early Class pointer diagnosis + +8 guard band-aid").
- **Dirty state**: Working tree dirty (launcher/docs mods + 1 local uncommitted edit in submodule `REDALERT/CONQUER.CPP`); stable is **2 ahead** of origin/stable (**2cbfcbe4fa07c0edb49a871183ab65de2debc469**); 1 stash ("On experimental: temp stash for stable branch test - launcher and doc changes from experimental visibility work"); `experimental` at **5c1505e93e30d598baeb8012474e3fb5af0b39fc** ("latest custom 4p visibility checkpoint (stability promotion + HUMAN_EARLY_STILL_UNKNOWN)"); `feature/copilot/initial-fixes` dead (no merges, zero strings in tree).
- Git-history-411: "Use `stable` (pinned at 6cd627a / submodule 3e53e4c) as the current daily-driver baseline." "least-broken for 'game actually starts and runs without immediate crash'." "Clean the dirty tree immediately" (uncommitted edit violates checklist). "experimental ... reportedly still broken".
- Deployed: Mixed sizes (Stable dev ~1.250816M post-2026-06-07 from pin; Vanilla-Plus 1.256448M May17; Aeloria-Experimental 1.270272M); live sibling polluted with 20+ .bak_* + recovery_20260607; Scripts/RedAlert.dll stray.

## True Root Cause of "No Units Visible" (1-2 Bullets, Cite Reports)
- **Overly aggressive guards at the 3e53e4c pin prune legit early objects before registration**: Starting rifle infantry (RTTI=28) / light tanks created in Read_INI/Create_Units (INFANTRY.CPP:3485+, SCENARIO.CPP etc.) + Unlimbo (OBJECT.CPP:1510, sets IsInLimbo=false, Map.Submit) under ScenarioInit; first post-0 Map.Render() / Get_Layer_State (DLLInterface.cpp:3861) / Cell::Draw_It (CELL.CPP:1286) hits Is_Drawable (OBJECT.H:333) -> Class_Is_Valid (INFANTRY.H:135 etc. for all 8 RTTIs) which does `uintptr_t effective = *(uintptr_t*)((const char*)this + 8); if (!Is_Plausible_Class_Pointer(effective)) { ... REJECTED ... at+8=0x%08X; return false; }` (OBJECT.H:304: high-byte 0x00/0x80/0x81 or misalign -> false; "TEMPORARY BAND-AID" comments cite observed garbage 0x00080000 / 0x80xxxx / 0x8073xxxx from packing/ODR/CCPtr/MI layout under /Zp1 + v145). Pruned from optr list (never reaches Draw_It or CC_Draw) -> never calls DLL_Draw_Intercept (DLLInterface.cpp:3464: Convert_Type + populate ObjectList) -> client C# gets no CNCObjectStruct entries (no sprite, no IsSelectable yellow box, no ID for input). See draw-pipeline-report §2-3 (exact trace), lifecycle-report §3-5 (timeline + why +8 garbage on fresh Unlimbo'd objects), 411-lowdown §2/4 (ranked #1), git-history-411 (guard introduced at pin).
- **ABI/packing hazard is root (transient early-lifecycle layout, not random corruption)**: Affects bulk-created starting units most (custom 4p + AI houses + immediate first render after ScenarioInit--); Class.Raw() often good at creation log but +8 (the "runtime offset the drawing code actually dereferences", not offsetof) is garbage during narrow post-ctor / first Map.Render window. Guards treat symptom (prevent 0xC0000005 in Get_Image_Data/Techno_Draw_Object/blitter/interop) at cost of visibility. DLL registration is *side-effect of draw calls only*. See draw-pipeline §6, lifecycle §6-7, 411 §2/3 (CONQUER.CPP:3434, DLLInterface.cpp:4012/3464).

## Why the 16x16 + Guards + "Exemption" Didn't Deliver Playable Units
- 16x16 feed (CONQUER.CPP:3450/3487 in the two CC_Draw_Shape(ObjectClass*) overloads: "Feed the client a minimal safe entry anyway so the unit can be visible/registered"; DLL_Draw_Intercept(...,16,16,...)) is **belt-and-suspenders last-line only** (rarely reached: pruned earlier in Is_Drawable/Draw_It/Cell prune for Infantry/Unit); even when hit, wrong tiny dims (client sprite/hitbox/selection broken), incomplete (no full Class_Of data always), no promotion path. See draw-pipeline §3/4/6 ("16x16 is insufficient"), lifecycle §7 ("does *not* result in client-visible/selectable unit"), 411 §6.
- **"Exemption"/grace/long human window/32x32/HUMAN_EARLY/per-object stability/REAL_FIRST/PLAYER_EXEMPTION_FRAME_COUNT=18000 etc. described in Stable-v1 notes (Docs/10-Aeloria-Stable-v1-Release-Notes.md:80: "Invisible units... long human exemption window and safe placeholder...") and comments were NEVER in the 3e53e4c pinned source** (confirmed by grep in draw-pipeline §4: "Absent in current on-disk source... only in later experimental submodule pointers (e.g. 49228664..., 0fa1cdd1... 'visibility checkpoint'; 09cc9507/5c1505e)"; "WIP" in experimental commits; Aeloria-Debug logs from ~12:20 runs showed grace strings but from pre-pin/exp DLLs). "The 16x16 + long exemption never existed together in the committed/deployed state". Guards + 16x16 alone = crash survival at total cost of units. See 411 §2/6/10 (addendum: "Visibility/invisibles were a *known limitation* of the guard layer from day one of Stable-v1"), git-history-411 (later layers only in exp pins), draw-pipeline §4, lifecycle §8/10 ("No implementation found... absent here").
- Result per reports: "map visible but no units + crash after 30-60s"; "even vanilla also broken"; Stable-v1 "20+ min sessions" but with "invisible units" admitted limitation.

## Launcher/Deploy Hygiene Problems (Selection Bug, Pollution, .bat Contract)
- **Profile selection bug (exact ps1 lines from audit + 411)**: Unconditional `$recommended = Get-NewestProfile` (line 421, walks $Profiles.Keys mtime only on dev/*/Data/RedAlert.dll); if (-not $Profile) { ... $Profile = ... else { $list[0] } } (lines 423-432, 440; $list from enum order, often Experimental/Vanilla first; "Newest" only annotates menu). Matches exact smoking-gun log (Launch-Aeloria_20260607_132655_595.log): "Newest profile detected: Stable" "Final selected profile: Vanilla-Plus" "Source DLL ...Vanilla-Plus... Size: 1256448" then "MOD=Vanilla-Plus" + 57s crash. "launched aeloria stable ... but no mods were working!". See launcher-audit §1/4, 411 §3/5/8.
- **AutoDeploy pollution + cross-profile**: -A/-B always copies *current build* (usually exp, 1270272 bytes) to *SelectedProfile*.DevPath (lines 113-146, 466+); Deploy-Profile full recursive copy (even under -NC). "Newest" meaningless for pinned Stable (intentionally May baseline). Sizes flip 125* <-> 1270272 across profiles same day. 20+ Aeloria-Stable.bak_20260607_* + recovery_20260607 (divergent Data/XML layout) in live; Scripts/RedAlert.dll stray; XML root vs Data/XML drift (full-zooms may be ignored). See launcher-audit §2/4 (15 enumerated ways), draw-pipeline §5, 411 §3/5/8.
- **.bat contract broken**: Launchers/Launch-Aeloria-Stable.bat is *dumb* direct `steam ... MOD=Aeloria-Stable -FastLaunch` (no size check, no ps1); relies on *prior* correct ps1 -Profile Stable -A -NC deploy + -NC finally ("NoCleanup active - leaving live mod folder as-is") to leave live Aeloria-Stable/ intact. Without explicit -P + -NC (or manual pin), reverts/pollutes. "The system is *close* ... but ... makes 'double-click ...' *not reliable*." .bat users get Vanilla/exp bits under "Stable" name. See launcher-audit §2/4/6/7 (cheat sheet + exact commands), 411 §3/8.
- Get-Newest + AutoDeploy + -NC requirement + no verification + .bat dumbness = "Stable .bat" delivers wrong profile/DLL.

## Minimal Actionable Next Steps (Clean Commands + Smallest Source Change + Test Protocol)
**From 411 §5/7/9 + git-history-411 § (exact commands) + launcher-audit §6 (cheat sheet) + lifecycle §10 (minimal diff) + draw-pipeline §7. Prioritize 1-2-3; one ps1 -B -A -NC + .bat cycle on 4p.**

1. **Clean to known state first (git-history-411 recommended snapshot + reset; do from Development\)**:
   ```
   git status
   git branch -vv -a
   git log --oneline -30 --graph --all --decorate
   git -C Source/Rampastring-MoreQoL rev-parse HEAD   # expect 3e53e4c
   git stash list
   git reflog | head -20
   git rev-parse stable          # 6cd627acebd6d75d001859bbbc2da551ed9c634c
   git rev-parse origin/stable   # 2cbfcbe4...
   git -C Source/Rampastring-MoreQoL status
   git -C Source/Rampastring-MoreQoL diff REDALERT/CONQUER.CPP
   git stash push -m "temp: uncommitted CONQUER edit..."
   git submodule update --init --recursive
   git checkout stable
   git status   # clean
   # (optional: git reset --hard origin/stable to drop 2 ahead)
   git -C Source/Rampastring-MoreQoL log --oneline -5   # confirm 3e53e4c
   ```
   (Also inspect sizes: Get-Item Mods\Red_Alert\Aeloria-Stable\Data\RedAlert.dll etc.; force-recover from .bak_recovery if polluted ~1270272.)

2. **Launcher hygiene (parallel, no source change; audit exact 1-line + 3-line)**:
   - Scripts/Launch-Aeloria.ps1: line 432 change `else { $list[0] }` to `else { if ($recommended) { $recommended } else { "Stable" } }` (makes omitted -Profile pick recommended/Stable).
   - In Invoke-AutoDeployDll (after ~136): `if ($script:SelectedProfile.Name -ne "Aeloria-Experimental") { Write-Log "AutoDeploy only for Experimental..."; return; }` (prevents 1270272 into Stable dev).
   - Update Launchers/README.txt + ps1 comments + checklist: "explicit -Profile Stable + -NC for .bat contract"; "after build, promote manually to Stable dev (don't rely on -A)".
   - Add post-deploy size check for Stable (if ~1270272 "CRITICAL: experimental DLL bits!").
   - Run: `.\Scripts\Launch-Aeloria.ps1 -Profile Stable -B -A -NC` (or without -A after manual pin); use -D for verbose draw logs.
   - Pure play: double-click Launchers\Launch-Aeloria-Stable.bat (or steam ... MOD=Aeloria-Stable).

3. **Smallest source change (lifecycle §10 + draw-pipeline §7; 411 §7 "smallest (relax in heuristic)" first; keep guards for native crash path; target VIRTUAL/remaster path for full registration)**:
   - In Class_Is_Valid (e.g. INFANTRY.H:135 and symmetric UNIT.H etc., after basic Class checks before/around +8):
     ```cpp
     uintptr_t effective = *(uintptr_t*)((const char*)this + 8);
     if (!Is_Plausible_Class_Pointer(effective)) {
         // ... existing REJECTED log ...
         if (Class.Is_Valid() && Is_Plausible_Class_Pointer((uintptr_t)Class.Raw())) {
             return true;  // trust Class evidence for early objects (bypasses +8 layout artifact)
         }
         return false;
     }
     return true;
     ```
   - In CONQUER.CPP (both CC_Draw_Shape(Object*) ~3450/3487): on !plausible reject, for `if (window == WINDOW_VIRTUAL)` feed full w/h/shapenum to DLL_Draw_Intercept (compute from shapefile or fallback); keep 16x16 only for !VIRTUAL (native blitter protection).
   - (Alt even smaller: delete +8 blocks from the 8 Class_Is_Valid overrides entirely; keep only in CC_Draw; update 16x16 to full on VIRTUAL.)
   - Commit *inside submodule first*, then outer pointer update. Do **not** add more guards. Do **not** wholesale promote experimental.

**Test protocol (411 §9 + git-history + audit cheat sheet + lifecycle §10)**:
- Snapshot git first (above commands).
- After hygiene + source relax + rebuild/deploy (-B -A -NC -Profile Stable; verify size !=1270272 in Stable dev/live; check Aeloria-Debug.log for "guard passed" + real (non-16) CC_Draw on starting units).
- Double-click Launch-Aeloria-Stable.bat (or ps1 equivalent); custom 4p skirmish with placed infantry+vehicles for human + AI.
- Success: "real riflemen sprites visible/selectable (yellow box)/orderable/move/shoot immediately (within 5-10s)", "2+ min stable play", "correct mods active (full zoom GameConstants)", "no immediate crash or 'no units visible'", logs show no REJECTED for player/AI starting RTTI_INFANTRY/UNIT or full-size DLL entries, no "Final selected Vanilla".
- Repro the 20260607 log scenario (omit -Profile sometimes) to confirm fix.
- Watch Logs/Aeloria-Debug_*.log + CrashReports; capture before/after.
- If from .bak recovery needed, use cheat sheet.
- "playable baseline restored" = above + update Stable notes + re-pin + commit minimal diff.

## Key Risks and What "Playable Baseline Restored" Looks Like
- **Risks**: Dirty tree + uncommitted CONQUER edit + ahead-of-remote = "works on my machine" crises (git-history). Rebuilds regress to guard-only (no grace). AutoDeploy/selection still pollutes without the ps1 fixes. Backport *only* proven visibility bits from exp pins (09cc9507/5c1505e etc.; test rigorously); "Do **not** promote experimental wholesale". No root ABI fix yet (packing/ctor/layout hazard remains; guards temporary per comments). Crashes can still occur post-exemption (per notes). .bat depends on prior correct deploy. "Even vanilla" means baseline DLLs also hit the window.
- **"Playable baseline restored"**: User double-clicks Launch-Aeloria-Stable.bat (or equiv), custom 4p skirmish loads with *visible, selectable, orderable* starting units (infantry + vehicles, player + AI; real sprites, yellow boxes, not 16x16 stubs), stable play for minutes (2+), correct mods (full zoom GameConstants_Mod.xml active), no immediate crash/"no units visible". Clean profiles (no pollution, sizes ~1256k baseline in Stable, no stray .baks affecting), explicit -P/-NC contract reliable, git clean at 3e53e4c (or improved pin). Then "commit the minimal diff *inside submodule first*, update outer pointer + Stable notes + Launchers/README, pin as playable-baseline."
- 411 handoff/lead synthesis: "Once 'units draw + no crash + .bat works' on 4p ... commit ... Do not add guards. Do not wipe." "The unfiltered truth ... is above". Reports fully consistent (no contradictions; addendum confirms).

(End. All backed by absolute paths, exact SHAs/lines/logs from the 6 read files. Ready for new owner to apply + resume dev. See full reports for deeper traces.)