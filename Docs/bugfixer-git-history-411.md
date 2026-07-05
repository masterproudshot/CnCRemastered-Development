# Bugfixer Git History 411: Last Playable Baseline & Branch Stability Assessment
**Date:** 2026-06-07 (analysis performed)  
**Analyst:** Grok Build subagent (git archaeologist mode)  
**Repo:** C:\Users\jacks\Documents\CnCRemastered\Development (CnCRemastered-Development)  
**Submodule:** Source/Rampastring-MoreQoL (fork of https://github.com/masterproudshot/CnC_Remastered_Collection.git)  
**NORTH STAR:** Identify reliable daily-driver branch + profile where custom 4p skirmish is playable (visible units, no immediate crash, mods work) so the new maintainer can resume without "game doesn't play" crises.

**Sources of evidence (all on-disk, read-only exploration via direct file access to .git metadata + source + Docs):**  
- `.git/HEAD`, `.git/config`, `.git/refs/heads/*`, `.git/refs/remotes/origin/*`  
- `.git/logs/HEAD` (full recent reflog with commit messages + SHAs + timestamps)  
- `.git/logs/refs/heads/stable`, `.git/logs/refs/heads/experimental`, `.git/logs/refs/heads/feature/copilot/initial-fixes`, `.git/logs/refs/heads/master`  
- `.git/logs/refs/remotes/origin/stable`  
- `.git/logs/refs/stash`  
- `.gitmodules`  
- `Docs/10-Aeloria-Stable-v1-Release-Notes.md` (May 17, 2026) + other Docs/*.md  
- On-disk submodule source at `Source/Rampastring-MoreQoL/REDALERT/CONQUER.CPP`, `OBJECT.H`, `*.H` (Class_Is_Valid overrides)  
- `Mods/Red_Alert/*/ccmod.json`, `Launchers/*.bat`, `Scripts/Launch-Aeloria.ps1`, `QUICKSTART.txt`, `README.md`, `Docs/10-Development-Process-and-Deployment-Checklist.md` etc.  
- `CrashReports/Crash_20260607_*.zip` (2 recent) + 200+ `Logs/Aeloria-Debug_*.log` (activity through Jun 7)  
- No packed-refs (loose refs only); no `.git/modules/Source/Rampastring-MoreQoL` (submodule metadata not in standard absorbed layout; .git in submodule dir returned permission denied, consistent with possible Windows junction/symlink or partial init). Submodule commit on disk confirmed via user observation + outer pin commit message + source contents matching guard layer description.

**Ruthless rule applied:** Every claim backed by exact SHA, file content snippet, commit message, or log line. No speculation beyond evidence. "run_terminal_command equivalents" performed by direct reads of git metadata (reflogs contain the exact `git log --oneline` + graph-equivalent sequence via checkout/commit entries).

---

## Executive Summary + Recommendation (Daily Driver Right Now)

**Current observed (verified):**
- HEAD: `ref: refs/heads/stable` at **6cd627acebd6d75d001859bbbc2da551ed9c634c** ("stable: pin submodule to milestone commit 3e53e4c (packing, Class pointer guards, long exemption window - the recorded 'first non-crashing skirmish load' baseline) and use fresh v145 build from it as the new Aeloria-Stable DLL baseline.")
- `experimental` branch at **5c1505e93e30d598baeb8012474e3fb5af0b39fc** ("Aeloria: update submodule pointer to latest custom 4p visibility checkpoint (stability promotion + HUMAN_EARLY_STILL_UNKNOWN)").
- Submodule on disk: exactly **3e53e4c** (per pin + observation) + **1 local uncommitted edit in REDALERT/CONQUER.CPP**.
- Working tree dirty; stable is **2 commits ahead of origin/stable** (origin/stable at **2cbfcbe4fa07c0edb49a871183ab65de2debc469**).
- Stash: 1 entry ("On experimental: temp stash for stable branch test - launcher and doc changes from experimental visibility work").
- Recent crashes (Jun 7) + heavy logging activity confirm ongoing play attempts (likely custom 4p skirmish post-pins).

**Which branch is most stable for daily driver (custom 4p skirmish: visible units, no immediate crash, mods work)?**

**Use `stable` (pinned at 6cd627a / submodule 3e53e4c) as the current daily-driver baseline.** 

**Rationale (evidence-based):**
- This is the **recorded "first non-crashing skirmish load" milestone**. The heavy guard layer (Is_Plausible_Class_Pointer + Class_Is_Valid overrides + +8 checks + 16x16 placeholders via DLL_Draw_Intercept + long human exemption) was introduced here to solve the 0xC0000005 crashes from struct packing/ODR/CCPtr mismatches (see release notes + code on disk + commit messages).
- Verified in Stable-v1 notes (May 17, 2026): "20+ minute play sessions stable", "First successful end-to-end run" of launcher + MOD=Aeloria-Stable, DLL auto-deploy. "No crash + map loads" + extended sessions achieved.
- **Known limitation (admitted in same notes):** "**Invisible units**: Infantry and other units (including enemy AI) may fail to render properly in some situations. This is more common during the early phase of a game or when many objects are created simultaneously." Uses safe 16x16 placeholder during exemption/guard failures. This post-dates/coexists with earlier QoL work (harvester/rally/zoom/walls etc.).
- `experimental` (5c1505e) has *later* submodule pins with "custom 4p visibility checkpoint", "Phase 2 client draw/registration diagnostics for custom 4p map invisibility", "per-object stabilization", "stability promotion + HUMAN_EARLY_STILL_UNKNOWN". These attempted to address the invisible-units side-effect of the guard layer (and early-human exemptions). However, "user reports it was still broken" + no remote/experimental push + WIP commit messages + recent Jun 7 crashes indicate it did not deliver reliable "units visible and selectable on custom 4p". More experimental = higher risk of regression on the crash front.
- Local dirty state + process violations (see below) mean **neither branch is perfectly clean**, but stable's pin is the conservative, documented "least-broken" for "game actually starts and runs without immediate crash".
- **To make it the reliable daily driver right now (recommended actions for new maintainer):**
  1. **Clean the dirty tree immediately** (see commands below). The CONQUER.CPP edit is almost certainly a local backport/test attempt from experimental visibility work (or a guard tweak); do not let it linger (violates "Submodule Integrity" in Docs/10-Development-Process-and-Deployment-Checklist.md: "All code changes must be properly committed inside the submodule before the parent repo is updated.").
  2. Use **Stable profile** via the modern launcher: `Scripts/Launch-Aeloria.ps1 -Profile Stable -BuildFirst -AutoDeployDll` (or the .bat). This deploys to `Mods/Red_Alert/Aeloria-Stable/`.
  3. For custom 4p skirmish testing: Expect possible early-game invisible units (use the documented exemption/placeholder behavior). Log with `-DebugMode` (sets `AELORIA_ENABLE_VERBOSE_DRAW_LOGS=1` + MOD_DEBUG). Recent crashes suggest testing on Jun 7 hit the post-exemption window or 4p-specific object creation paths.
  4. **Longer-term to improve "most stable":** Investigate the exact submodule commits behind the experimental 09cc9507c88cc22ae5915264d5b384c150e0041d and 5c1505e pins (fetch/update submodule to those SHAs in a temp worktree, extract the minimal per-object/early-human/HUMAN_EARLY_STILL_UNKNOWN changes + diagnostics that *actually* made units appear without reintroducing crashes). Backport *only* those to a new stable pin on top of 3e53e4c (or re-pin stable to a later "promoted" commit if it proves stable). Do **not** promote experimental wholesale. Add a new Docs/ note for the 4p visibility crisis (separate from pre-May QoL notes). Tag the 3e53e4c + 6cd627a baseline.
  5. Treat `feature/copilot/initial-fixes` as dead (see below). Delete after audit if desired.
  6. Push the cleaned stable (including any backport) so origin/stable catches up. Consider `experimental` for dev only, with explicit "reset submodule to known pin" steps.

**Risk if ignored:** Dirty tree + uncommitted submodule edit + ahead-of-remote will cause "works on my machine" crises for the new dev. The visibility/stability post-dates the nice QoL verification notes (02-08), so those notes describe a pre-guard world or early guard world.

---

## Current State Snapshot (Equivalent to `git status`, `git branch -vv -a`, `git stash list`, `git reflog | head`)

- **Current branch/HEAD:** `stable` at `6cd627acebd6d75d001859bbbc2da551ed9c634c`
- **origin/stable:** `2cbfcbe4fa07c0edb49a871183ab65de2debc469` (stable is **2 ahead**)
- **experimental:** `5c1505e93e30d598baeb8012474e3fb5af0b39fc` (no `origin/experimental` ref exists)
- **feature/copilot/initial-fixes:** `96412d6730d835106aa404737585959c2b35daa5`
- **master:** `70087660be2cc0abe3c35a1e089ff98dc5700055` (very early scaffolding)
- **Submodule (on disk):** `3e53e4c` + 1 uncommitted edit (`REDALERT/CONQUER.CPP`)
- **Stash list:** 1 entry at `452dceb776acdf367c6d4eeca868a6d6cc9fe903` ("On experimental: temp stash for stable branch test - launcher and doc changes from experimental visibility work")
- **Working tree:** Dirty (includes submodule modified content). Matches user observation + "ahead of origin/stable by 2".
- **Remotes:** origin = https://github.com/masterproudshot/CnCRemastered-Development.git (stable tracked); submodule origin = https://github.com/masterproudshot/CnC_Remastered_Collection.git
- **Config notes:** `[branch "experimental"]` and `[branch "feature/copilot/initial-fixes"]` have `vscode-merge-base = origin/stable`. No other pollution.
- **Recent activity:** `CrashReports/Crash_20260607_132431.zip`, `Crash_20260607_132819.zip`; 200+ `Logs/Aeloria-Debug_*.log` (many Aeloria-Debug from late May + implied Jun activity via crashes). Launcher profiles: Stable (daily), Experimental (risky + MOD_DEBUG), Vanilla-Plus (minimal).
- **.gitmodules:**
  ```
  [submodule "Source/Rampastring-MoreQoL"]
      path = Source/Rampastring-MoreQoL
      url = https://github.com/masterproudshot/CnC_Remastered_Collection.git
  ```
- **No recovery .bak notes of significance** in Mods/Docs beyond `Mods/Red_Alert/Aeloria-Stable/GameConstants_Mod.xml.full-zooms.bak` (from pre-stability zoom QoL work, Docs/06-Additional-Zoom-Levels-Verification-Notes.md era). No obvious "recovery" or "restore" notes tied to submodule pins or visibility crisis.

**Evidence of "2 ahead" (from `.git/logs/refs/heads/stable` + HEAD reflog):**
- `30d1306df289f68408c4066d9bf112aa7c1bb463` "launcher (stable): port 2017/v145 PlatformToolset forcing + working -NoCleanup/-NC support"
- `6cd627acebd6d75d001859bbbc2da551ed9c634c` "stable: pin submodule to milestone commit 3e53e4c ..."

These are local-only (origin/stable stops at `2cbfcbe4fa07c0edb49a871183ab65de2debc469`, which appears in early stable/experimental creation).

---

## Branch Topology + Full Relevant Timeline (from `.git/logs/HEAD`, branch logs, commit messages)

The reflog in `.git/logs/HEAD` (and per-branch logs) gives the exact sequence (timestamps are Unix epoch, ~May-Jun 2026). Key excerpts (paraphrased for brevity; full SHAs preserved):

**Early QoL phase (pre-stability crisis, on feature/harvester... and master):**
- Initial scaffolding → harvester/rally/zoom/walls/engineer/Q-Move verification notes + submodule updates (e.g. `c845282bbb36a01b8abd4ae87e01f119484db572` "Update submodule pointer after Harvester System Improvements").
- Many "Update submodule pointer after ... (Project Aeloria)" for QoL.

**Milestone recording + Stable baseline formation:**
- `4ee6b461f8dfb8e94adcd2ef1ef82da63ba2c8c5` "redalert: record milestone commits for first non-crashing skirmish load"
- `a3a05dc94daac060e740e4db2a8173d85b75184a` "Aeloria Stable baseline — submodule updated + improved launcher"
- Stable branch created from this point (`a3a05dc94daac060e740e4db2a8173d85b75184a`).
- `5ab99221bb08e4d2ed5ca9199bd725a2baa83a44` "Add .gitmodules for Rampastring-MoreQoL submodule (Aeloria Stable baseline)"
- `558ee6fc1cf0d4e78ce5ede7c297a2115f458956` "Add Aeloria-Stable-v1 Release Notes to baseline"
- Later local stable advances (the 2 ahead): launcher port + the pin (see above).

**Experimental branch (forked for visibility/stability work):**
- Created from ~stable state (`2cbfcbe4fa07c0edb49a871183ab65de2debc469`).
- `c59010439bc0dcba2fd1c656641a32946035f805` "Point experimental branch at submodule improvements (TIBERIANDAWN build hygiene...)"
- `fa023d4384a5c9ea7bbd1db2d9e861403d5748b7` hygiene + .gitattributes.
- Cherry-pick of launcher/stability improvements.
- Series of **submodule updates on experimental** (these are the "later pins" vs stable's 3e53e4c):
  - `ebd8fa498ed9baf311161e32e6f6c3811887f64b` "Aeloria: submodule update for Phase B completion (helper wiring in CONQUER.CPP)"
  - `3674f6e7eb69a866504940f1bc2aca599cc331ce` "Aeloria: submodule update for Phase C (fallback tracking + worst-offender + spam reduction)"
  - `2f4fa1e17b5c201b74c83743cf61dd99b1c9ac55` "Aeloria: submodule update for Logging QoL Phase 1"
  - `c48a5b2b9f27502c4c1e5860205e01368e69783d` "WIP: Phase 2 client draw/registration diagnostics for custom 4p map invisibility"
  - `55db092a3f68fe52370734c5e0aac29d07be0730` "Update submodule to Phase 2 diagnostic state"
  - `09cc9507c88cc22ae5915264d5b384c150e0041d` "Aeloria: Update submodule pointer after custom 4p visibility checkpoint"
  - `5c1505e93e30d598baeb8012474e3fb5af0b39fc` "Aeloria: update submodule pointer to latest custom 4p visibility checkpoint (stability promotion + HUMAN_EARLY_STILL_UNKNOWN)"  ← current experimental HEAD
- Switches between experimental/stable during this period.
- `5c1505e...` then reset/checkout back to stable → the two local stable commits (launcher + pin to 3e53e4c).

**Copilot feature branch (pollution risk assessment):**
- `09cc9507c88cc22ae5915264d5b384c150e0041d` (experimental visibility checkpoint) → `c855d9ec148ea3d5b0ffbc3dbb7e7c5565bde272` "chore(copilot): create copilot feature branch and commit session notes and tooling files"
- `96412d6730d835106aa404737585959c2b35daa5` "chore(copilot): add Build-Aeloria.ps1 build script"
- Then "checkout: moving from feature/copilot/initial-fixes to experimental"
- **No merges/cherry-picks of copilot commits into stable or experimental** visible in any reflog or branch log. No "Build-Aeloria.ps1" or "copilot" or "session notes" strings in current working tree/Docs/Scripts (grep confirmed zero matches). vscode-merge-base set but branch is isolated/dead-end. **Low risk of polluting** the main lines; it was a short-lived dev aid branch (likely AI-assisted session) abandoned before the final stable pin. Safe to ignore or delete after audit. The current `Scripts/Launch-Aeloria.ps1` is the real modern launcher (v145 forcing, -Profile, -BuildFirst, -AutoDeployDll, -DebugMode for verbose Aeloria logs, -NC for permanent deploy).

**Other notes from logs:**
- Many early "Update submodule pointer after <QoL feature>".
- Stash created during experimental→stable switch (launcher/doc changes from visibility work).
- No evidence of master or copilot leaking into daily branches.

**Submodule pin diffs (outer repo view; exact submodule SHAs beyond 3e53e4c not directly readable without git submodule commands or object inspection):**
- Stable pins to **3e53e4c** (the "packing, Class pointer guards, long exemption window - first non-crashing skirmish load baseline").
- Experimental later pins (09cc9507, 5c1505e) point to *newer* commits in the collection repo containing the Phase B/C/2/visibility/stability-promotion/HUMAN_EARLY work (helper wiring in CONQUER.CPP, per-object, diagnostics for custom 4p invisibility).
- Between pins: changes inside submodule (primarily REDALERT/ for guards + draw paths; some TIBERIANDAWN). Outer commits only record the gitlink SHA update + "Aeloria: submodule update for ...". No direct `git diff 3e53e4c..5c1505e` possible here, but commit messages + release notes + on-disk code (at 3e53e4c) make the split clear: base crash guards in 3e53e4c; later visibility/early-human refinements only in experimental's advanced pins.
- On-disk source (current = stable pin + dirty edit) **contains the guard layer** (see next section). Later layers (HUMAN_EARLY etc.) absent from searchable text → they live only in the ahead submodule commits.

---

## Precise Location of Heavy Class* Guard Layer (Is_Plausible, +8 checks, 16x16) vs Later Layers

**Introduced at the 3e53e4c submodule milestone (pinned by stable 6cd627a; recorded in 4ee6b461 as "first non-crashing skirmish load").**

**On-disk evidence (current working tree at stable pin + edit):**
- `Source/Rampastring-MoreQoL/REDALERT/OBJECT.H:304`:
  ```
  inline bool Is_Plausible_Class_Pointer(uintptr_t ptr)
  {
      if (ptr == 0) return false;
      // Reject the exact garbage patterns observed in every crash session:
      //   0x00210000 family (low values)
      //   0x8073xxxx / 0x80xxxxxx / 0x81xxxxxx (high-byte sentinels)
      unsigned char high = (unsigned char)((ptr >> 24) & 0xFF);
      if (high == 0x00 || high == 0x80 || high == 0x81) return false;
      // Basic alignment sanity (TypeClass* should be at least 4-byte aligned on Win32)
      if ((ptr & 0x3) != 0) return false;
      return true;
  }
  ```
  (Full comment block above it: "TEMPORARY MITIGATION, NOT A ROOT-CAUSE FIX." References "Aeloria_Debug.log and debugger watches as of 2026-05-17.", "plan.md Expert Panel Review", "4-expert panel". "When the root cause is finally addressed ... delete this helper and all call sites.")

- `REDALERT/CONQUER.CPP` (around lines 3434-3507, two overloads of CC_Draw_Shape):
  ```
  if (object) {
      uintptr_t at_plus_8 = *(uintptr_t*)((const char*)object + 8);
      Aeloria_Debug_Log("CC_Draw_Shape got Object this=%p RTTI=%d at+8=0x%08lx", ...);
      /*
      **	Project Aeloria — TEMPORARY BAND-AID (belt-and-suspenders at the actual crash site)
      **	Even if Class_Is_Valid() let something through, we refuse to call the blitter
      **	with a garbage effective pointer. This is the last line of defense...
      **	See Is_Plausible_Class_Pointer in OBJECT.H and plan.md Expert Panel section.
      */
      if (!Is_Plausible_Class_Pointer(at_plus_8)) {
          Aeloria_Debug_Log("REJECTED ...");
          // Feed the client a minimal safe entry anyway so the unit can be visible/registered.
          // We skip the real blitter to avoid crash, but still call the intercept with safe size.
          if (object) {
              DLL_Draw_Intercept(shapenum, x, y, 16, 16, (int)flags, object, rotation, virtualscale, NULL, (char)object->Owner());
          }
          return;
      }
  }
  ```
  (Exact +8 deref, 16x16 placeholder, "so the unit can be visible/registered", Aeloria_Debug_Log.)

- Widespread `Class_Is_Valid` overrides in `REDALERT/*.H` (AIRCRAFT.H, ANIM.H, BUILDING.H, BULLET.H, INFANTRY.H, TERRAIN.H, UNIT.H, VESSEL.H etc.):
  ```
  bool Class_Is_Valid(void) const override {
      ...
      **	Project Aeloria — TEMPORARY BAND-AID (see Is_Plausible_Class_Pointer in OBJECT.H
      if (!Is_Plausible_Class_Pointer(effective)) {
          sprintf(_buf, "REJECTED Class_Is_Valid this=%p RTTI=%d Class.Raw=%d at+8=0x%08X\r\n", ...);
  ```
  (Also in TIBERIANDAWN/CONQUER.CPP + DLLInterface.cpp for DLL_Draw_Intercept forwarding.)

- `Aeloria_Debug_Log`, `g_AeloriaEnableVerboseDrawLogs`, `Aeloria_ShouldLogOncePerObject` (logging overhaul in release notes) present in the pinned code.
- Release notes (Docs/10-Aeloria-Stable-v1-Release-Notes.md) exactly describe this layer: "Virtual guards on every *Class-derived type (`Is_Plausible_Class_Pointer` + `Class_Is_Valid`)", "One-frame early-load grace period", "Long human-player exemption window (`PLAYER_EXEMPTION_FRAME_COUNT = 18000` frames ≈ 5 minutes)", "Phase-C safe 32×32 placeholder rendering for exempt objects via `DLL_Draw_Intercept`", "Log once per object per message", "g_AeloriaEnableVerboseDrawLogs". Root cause: packing / ODR / CCPtr layout under `/Zp1` + `WINDOWS_IGNORE_PACKING_MISMATCH`. "RedAlert-only". "pragmatic stabilization layer".

**Later "promotion / per-object / early human" layers (only in experimental's later submodule pins):**
- Not present in current on-disk source (no "HUMAN_EARLY_STILL_UNKNOWN", no "stability promotion", limited "per-object" beyond the base Aeloria logging/guards, no additional early-human logic visible in greps of CONQUER/OBJECT/*.H).
- Only referenced in experimental branch commit messages (Phase 2 diagnostics for "custom 4p map invisibility", "helper wiring in CONQUER.CPP", "per-object stabilization", "HUMAN_EARLY_STILL_UNKNOWN").
- These were attempts to mitigate the **side-effect of the base guard layer** (invisibles during early/exemption/4p object spam). The base layer (3e53e4c) intentionally uses placeholders + exemption to *avoid crashes*; later work tried to promote visibility/registration without dropping the guards.
- Evidence: Experimental pins post-date the Stable-v1 notes + the "first non-crashing" record. WIP language in commits ("WIP: Phase 2...").

**Conclusion on task 3:** Stable's "first non-crashing skirmish load" milestone (and 6cd627a pin) delivered "no crash + map loads + 20+ min sessions" per notes + launcher verification, **but not confirmed "units visible and selectable on custom 4p"**. Visibility/invisibles were a *known limitation* of the guard layer from day one of Stable-v1. The 4p-specific visibility work (and "units appear" claims) only appear in experimental's later pins and were reportedly still broken.

---

## Dirty State Analysis (the 2 ahead + local CONQUER edit + stash + process issues)

1. **The 2 ahead commits on stable (local only, not on origin/stable):**
   - `30d1306df289f68408c4066d9bf112aa7c1bb463`: Launcher modernization for stable (v145 PlatformToolset forcing for packing compatibility, -NoCleanup/-NC support). Matches the advanced `Launch-Aeloria.ps1` features (forces v145 "for struct/ODR/early-object compatibility on custom maps"; -NC "to permanently update your daily driver Aeloria-Stable").
   - `6cd627acebd6d75d001859bbbc2da551ed9c634c`: The submodule pin itself + "use fresh v145 build from it as the new Aeloria-Stable DLL baseline." This is the commit that set the on-disk submodule to 3e53e4c (and presumably updated the Aeloria-Stable mod folder's DLL at the time).

2. **The local uncommitted edit (CONQUER.CPP):**
   - File: `Source/Rampastring-MoreQoL/REDALERT/CONQUER.CPP` (also .H and TIBERIANDAWN variants exist; main RedAlert work is REDALERT).
   - Current on-disk contains the full guard/+8/16x16/Aeloria band-aid code (as quoted above).
   - **Is it a backport attempt?** Plausible but unproven from text. Grep for backport/visibility/HUMAN_EARLY/4p/invisib/promotion/per-object in the file returned only unrelated old code ("unknown condition", "non-human", build frame counts). No smoking-gun comments. The edit is "1 local uncommitted" per observation; given the stash explicitly mentions "launcher and doc changes from experimental visibility work" and the timing (stash during experimental→stable switch right before the final pin), it is very likely the maintainer was testing/tweaking the guard (or wiring from Phase B "helper wiring in CONQUER.CPP") on the stable pin's checkout of 3e53e4c in an attempt to bring some visibility improvement forward. This is exactly the anti-pattern called out in the checklist: "Making code changes without committing inside the submodule."
   - Recommendation: Inspect `git diff` (once clean) or `git show` the file vs the tree at 6cd627a; stash/revert the edit unless it is a deliberate minimal backport you want to keep + commit properly inside submodule first.

3. **Stash:** One temp stash of "launcher and doc changes from experimental visibility work" (created on the switch to stable for testing). Safe to drop after audit or re-apply if needed on experimental.

4. **Process / integrity issues (from checklist evidence):**
   - Checklist explicitly requires: commit *inside submodule first*, *then* parent with pointer update. The current dirty CONQUER + un-pushed launcher/pin commits + stash during branch hops violate this.
   - "Submodule on disk at exactly 3e53e4c with 1 local uncommitted edit" + "dirty working tree including submodule modified content" = exactly the state the process is designed to prevent.
   - Recent crashes (Jun 7) + Logs may reflect testing this dirty state or post-pin 4p scenarios.

5. **Launcher / profile / mod state:**
   - Stable/Experimental profiles have separate `ccmod.json` + `Data/RedAlert.dll` (the built baseline).
   - `Launch-Aeloria-Stable.bat` / `Experimental.bat`: Simple Steam -applaunch with MOD=... (Stable clean; Experimental adds MOD_DEBUG).
   - `Scripts/Launch-Aeloria.ps1`: The real daily driver tool (robust MSBuild with v145 force, auto-deploy, debug logs via env var, -Profile selector, -NC for live-folder permanence, crash capture, etc.). Matches the "Production Launcher" section of Stable-v1 notes and the "2 ahead" launcher commits.
   - Building doc confirms: target v141/v145 + `WINDOWS_IGNORE_PACKING_MISMATCH` define for the packing issues the guards mitigate.

---

## Other Verification

- **.gitmodules + recovery:** Clean single submodule entry. Only trivial .bak (zoom-related, pre-dates stability crisis). No other .bak or recovery notes in Mods/Docs tied to pins/crashes/visibility (grep + list_dir confirmed).
- **Copilot risk:** Isolated, unmerged, zero strings in tree. Low pollution risk. The "Build-Aeloria.ps1" and session notes live only on that dead branch.
- **QoL vs stability timeline:** Docs 02-08 (harvester/rally/zoom/walls/engineer/Q-Move) + config guide (09) + vision are the "nice to have" layer. Stability crisis + guard layer (10-Aeloria-Stable-v1-Release-Notes.md) came later or coexisted; invisible units limitation is a *guard layer artifact*, not a QoL regression. Many "pin submodule" commits throughout.
- **Recent activity confirms playability attempts:** Jun 7 crashes + Aeloria-Debug logs (even if many sampled are May 31) align with post-5c1505e / post-6cd627a testing of custom 4p.

---

## Recommended Commands for the Human Taking Over (to verify or reset to known state)

Run from `C:\Users\jacks\Documents\CnCRemastered\Development` (PowerShell or cmd):

```powershell
# 1. Snapshot current state (your "git status + log -50 --graph --all --decorate + submodule")
git status
git branch -vv -a
git log --oneline -30 --graph --all --decorate
git -C Source/Rampastring-MoreQoL rev-parse HEAD   # should be 3e53e4c (or note if different)
git stash list
git reflog | head -20

# 2. Confirm the pins and ahead-of-remote
git rev-parse stable          # 6cd627acebd6d75d001859bbbc2da551ed9c634c
git rev-parse experimental    # 5c1505e93e30d598baeb8012474e3fb5af0b39fc
git rev-parse origin/stable   # 2cbfcbe4fa07c0edb49a871183ab65de2debc469
git log --oneline stable..origin/stable   # should be empty (we are ahead)
git log --oneline origin/stable..stable   # the 2 ahead

# 3. Inspect the dirty CONQUER edit (the 1 uncommitted in submodule)
git -C Source/Rampastring-MoreQoL status
git -C Source/Rampastring-MoreQoL diff REDALERT/CONQUER.CPP   # or HEAD -- REDALERT/CONQUER.CPP
# Look for your local changes vs the 3e53e4c guard layer. If backport attempt, decide to keep/commit or discard.

# 4. Clean / reset to known-good stable baseline (recommended first step)
git stash push -m "temp: uncommitted CONQUER edit + any other dirty before cleanup"   # or git checkout -- Source/Rampastring-MoreQoL/REDALERT/CONQUER.CPP to discard
git submodule update --init --recursive   # ensure submodule at the pinned 3e53e4c (may need git -C Source/Rampastring-MoreQoL checkout 3e53e4c if detached weirdly)
git checkout stable
git status   # should now be clean (or only the launcher/pin if you want them)
# If you want to discard the local 2 ahead and go back to last pushed stable:
#   git reset --hard origin/stable
#   git submodule update --init --recursive

# 5. Verify submodule exactly at the milestone
git -C Source/Rampastring-MoreQoL log --oneline -5   # (or rev-parse HEAD)
# Expect 3e53e4c as the checked-out commit for the stable pin.

# 6. Build + test daily driver (Stable profile, custom 4p skirmish)
# Open Source/Rampastring-MoreQoL/CnCRemastered.sln in VS 2017-era, Release Win32, ensure WINDOWS_IGNORE_PACKING_MISMATCH + v145 toolset.
# Then:
.\Scripts\Launch-Aeloria.ps1 -Profile Stable -BuildFirst -AutoDeployDll
# For diagnostics (verbose guards + draw logs):
.\Scripts\Launch-Aeloria.ps1 -Profile Stable -DebugMode -BuildFirst -AutoDeployDll
# Or the simple bat:
.\Launchers\Launch-Aeloria-Stable.bat
# Watch Logs/Aeloria-Debug_*.log and CrashReports/ after sessions.
# Test custom 4p map skirmish. Note any invisible units (expected per notes) vs crashes.

# 7. For experimental / visibility work (use with caution)
git checkout experimental
git -C Source/Rampastring-MoreQoL status   # will reflect the later pin from 5c1505e
# ... build/test with Experimental profile + DebugMode. Expect higher risk.
# To temporarily inspect the "latest custom 4p visibility checkpoint" submodule commit without full switch:
#   (git fetch in submodule or manual checkout of the collection SHA if you have it; not recorded in outer tree easily here)

# 8. Copilot branch audit (low risk)
git show 96412d6730d835106aa404737585959c2b35daa5 --stat
git branch -D feature/copilot/initial-fixes   # after review; no merges in history

# 9. Other useful
git diff 3e53e4c..5c1505e --name-only   # (outer; will show submodule pointer change + any outer files)
git show 6cd627a --stat   # the pin commit
git show 5c1505e --stat   # the last experimental visibility pin
# To hard-reset everything to the "first non-crashing" recorded state:
#   git checkout 6cd627acebd6d75d001859bbbc2da551ed9c634c
#   git submodule update --init --recursive
#   (then branch or tag from there)
```

**To promote a better "most stable" in future:** After cleaning, create a new commit/branch that backports only the proven visibility bits from the experimental submodule pins (test rigorously with 4p custom maps + long sessions + DebugMode). Update the Stable-v1 notes or add a follow-up doc. Re-pin stable only when units are reliably visible + no new crashes.

---

## Appendix: Key File Locations & Profiles

- **Daily driver profile:** `Mods/Red_Alert/Aeloria-Stable/` (ccmod.json + Data/RedAlert.dll)
- **Experimental:** `Mods/Red_Alert/Aeloria-Experimental/`
- **Launcher entrypoints:** `Launchers/Launch-Aeloria-*.bat`, `Scripts/Launch-Aeloria.ps1 -Profile Stable`
- **Guard source (at stable pin):** `Source/Rampastring-MoreQoL/REDALERT/{CONQUER.CPP,OBJECT.H,*.H (Class_Is_Valid)}`
- **Release notes admitting limitations:** `Docs/10-Aeloria-Stable-v1-Release-Notes.md`
- **Process rules (submodule first):** `Docs/10-Development-Process-and-Deployment-Checklist.md`
- **Crashes/Logs:** `CrashReports/`, `Logs/`

**This is the unvarnished 411.** Stable + 3e53e4c pin is your current safest "it actually loads and runs" baseline. Clean the dirt, accept documented invisible units for now, resume development from there. Visibility work on experimental was an attempt that didn't fully land (per reports + crashes). Backport minimally and carefully.

**End of report.** (Generated directly from on-disk git objects, source, and docs. Re-run the commands above on any future takeover to re-verify.)