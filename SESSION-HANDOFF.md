# SESSION HANDOFF: North Star for Aeloria-Experimental (Custom 4p Skirmish)

**Date:** 2026-06-07  
**Branch:** experimental  
**Context:** This session ended with user frustration ("this suck, I quit.") after repeated "game crashed on skirmish launch" on clean runs. The goal (north star) was not achieved in this session, but significant WIP was done on the decoupled client registration layer. A brand new Grok session should start fresh by reading this document FIRST.

## North Star (verbatim target)
User (or simple .bat) launches, custom 4p skirmish on the target map shows visible, selectable, orderable starting infantry + vehicles for the human house (and AI), game is stable for minutes of actual play, mods (full-zoom GameConstants etc.) are active, no immediate crash or "map but no units" experience. "Launch-Aeloria-Experimental.bat just works for a playable custom 4p skirmish."

## Current Code State (what the new session inherits)
- The main work is committed as a WIP commit inside the Rampastring-MoreQoL submodule (pointer updated in superproject).
- Core file: `Source/Rampastring-MoreQoL/REDALERT/DLLInterface.cpp`
  - Get_Layer_State bulk section (~4991+): Complementary bulk registration for hasCreation objects (from g_AeloriaObjectCreationFrame, seeded at Unlimbo in TECHNO.CPP).
    - Uses *local* `bulkAdded` counter (Step 4: no sharing with `CurrentDrawCount` from normal layer walk — avoids stomping/offset bugs).
    - Appends cleanly after final normal `TotalObjectCount`.
    - `FIRST_EXPORT_WITH_GRADUATED_UNITS` log (includes `_export_count`, `bulk_grads_added`, `finalCount`, `human_at_bulk`).
    - `BULK_POST_COUNT` with `cur_from_bulk=0` (proves separation).
    - Enriched population: pixel `PositionX/Y` (via `Coord_To_Pixel`), full flush-mirrored safe fields (DrawFlags, ShapeIndex, Rotation, Scale, RecentlyCreated, IsNominal, IsAntiGround etc.), RemapColor via house walk, Can*/ActionWithSelected for owner, etc.
  - Stepping hook: Re-enabled at the end of Get_Layer_State (after BULK_POST). `__debugbreak()` (MSVC) right after the first export with graduated units. Comment has full VS attach / cdb instructions.
- Other related (from history, check for dirt): Unlimbo force in TECHNO.CPP, AeloriaObjectStability / Is_Player_Exempt in OBJECT.H (graduated clientListInserted bypass, stabilityLevel).
- Hook was disabled for some clean validation runs, re-enabled in the final launch of this session.
- Build: Use v145, Release (Debug config has pre-existing C5298 warnings from win32lib headers treated as errors under /WX). ps1 handles -B -A -NC -D for Experimental.
- Launcher: Scripts/Launch-Aeloria.ps1 + Launchers/Launch-Aeloria-Experimental.bat (modified in this session; use explicit `-Profile Experimental`).

## Latest Run Evidence (self-monitored, ID a702a084-6d99)
- Clean? No — this was the debug run with hook re-enabled.
- Bulk/grad: 18 graduated (owners 12/13/14/15, good 4p coverage this time), pixel pos, etc.
- Logs (firing as designed):
  - `BULK_COMPLETED_FOR_GRADUATED N=18 ... human=14 (step4 guard)`
  - `FIRST_EXPORT_WITH_GRADUATED_UNITS _export_count=0 bulk_grads_added=18 finalCount=18 human_at_bulk=14`
  - `BULK_POST_COUNT total=18 cur_from_bulk=0 finalCount=18 human_house_at_this_export=14`
- Then: immediate process exit (the `__debugbreak()` — expected). Crash zip generated. No game time, no visible units reached by user.
- In prior *clean* run (hook disabled, ID 4160f8c1): Similar but N=3 (only human house 12 in that snapshot), creations for AI houses occurred but limited bulk in first export, same post-BULK_POST crash.
- Pattern across runs: The registration layer (Unlimbo tracking + safe fills + bulk + graduation + Count update + richness) works. The client (remaster) receives the LAYERS buffer with our graduated early starting units — then crashes on skirmish launch. (Likely data issue in the CNCObjectStruct slots, timing of first export, or client-side handling of "early" objects.)

Root cause context (from bugfixer docs in repo): Packing/ABI hazard (/Zp1 + v145) causes early Unlimbo'd units to have bad +8 (Class*) during ScenarioInit / first render. Native guards prune them (or give 16x16 stubs). Our client-side bypass feeds the transient LAYERS ObjectList directly.

## Approved Plan Summary (for new session to follow; full details in session's plan.md if accessible, but this is the executable core)
Prioritized next steps (from the approved plan at session close; short cycles, clear announces, self-monitor logs, wait for user play/debug feedback):

1. **Re-enable stepping hook + targeted debug run** (already done in last launch of this session — use as starting point). Attach VS/cdb at break. Inspect: `ObjectList->Count`, the graduated `CNCObjectStruct` slots (0..N-1) — look at `PositionX/Y`, `AssetName`, `RemapColor`, `CanMove`/`CanFire`, `Strength`, enriched fields, `CNCInternalObjectPointer`, any zeros/bad values, SortOrder, etc. Callstack into client LAYERS consumption. Report exact findings.

2. **Ensure full 4p starting forces bulked** (house-agnostic). Why only 3 (or varying N) sometimes, and why not all AI houses in every first export? Broaden triggers if needed. Make sure creations for all houses (human + AI) reach bulk with !clientListInserted.

3. **Append graduated at *very end* of buffer** (plan suggestion to avoid ordering/stomping with normal batch). Modify bulk to use high indices (e.g. start near 511 and decrement, or collect then append after normal Total + set Count high enough). Re-test.

4. **Further richness / client-safe data** (if step 1 inspection shows gaps). Mirror even more from the direct flush path. Fix any fields that cause client AV or bad sprites/selection on first export.

5-7. Maintain launcher hygiene, run strict validation loops (clear announce every ps1 -Profile Experimental -B -A -NC -D, self-monitor newest Aeloria-Debug_*.log via dir, user reports units visible/selectable/orderable for human+AI? stable? zoom? ), commit on gate, update docs.

**Test command (always clear announce):**  
`powershell -ExecutionPolicy Bypass -File .\Scripts\Launch-Aeloria.ps1 -Profile Experimental -B -A -NC -D`  
(For debug runs: hook must be enabled in source. For clean play tests: disable temporarily.)

## How a New Session Should Start (direct instructions for the next Grok)
1. **Read this SESSION-HANDOFF.md FIRST** (and the approved plan.md from the old session dir if you can access the prior .grok session).
2. `cd` to the workspace (C:\Users\jacks\Documents\CnCRemastered\Development).
3. `git status` + `git log --oneline -3` to confirm you're on experimental with the WIP submodule commit.
4. Check the current state of the stepping hook in DLLInterface.cpp (around line 5202+).
5. Self-monitor: Run a launch with the ps1 (clear announce in your output: "=== CLEAR BUILD+LAUNCH (continuing from handoff, step 1 debug) ==="), then use dir/Get-ChildItem to find newest Aeloria-Debug_*.log and Crash_*.zip without asking the human.
6. When the hook hits (on first bulk export with graduated units): Instruct/ guide the user to attach debugger. Analyze the buffer content.
7. Iterate short cycles per the plan bullets above. Always:
   - Clear announce before any ps1 launch.
   - Wait for user play/debug feedback before deep analysis or next launch ("launch running now... YOU play... report observations").
   - Print the current plan 1-x bullets at end of responses.
   - Use the north star definition as the gate.
8. Key files to focus: DLLInterface.cpp (bulk + hook), related (TECHNO.CPP Unlimbo, OBJECT.H stability).
9. If user frustration appears again: Acknowledge, focus on small actionable next edit + clean launch, be transparent about progress vs. north star.

## What Was Committed in This Session Close
- Inside submodule (Rampastring-MoreQoL): The DLLInterface.cpp changes (bulk guards, richness, hook) as a clear WIP commit.
- Superproject: Updated submodule pointer + this SESSION-HANDOFF.md.
- **Not committed (left dirty for user review or new session):** Launcher/ps1/Launchers modifications (may be user-specific tweaks). Various untracked Docs/ bugfixer reports (valuable analysis — new session can git add if desired). Do `git status` on arrival.

## Known Frustrations / Advice for New Session
User was unhappy with repeated crashes on launch despite the registration layer working in logs. The "decoupled" bypass gets some (or many) units into the client's first LAYERS, but something (data, timing, client expectations, or only partial forces) still causes immediate exit before playable skirmish. Use the stepping hook aggressively in the next session to look *inside* the buffer at the crash point — that's the highest-leverage info now.

The old session plan.md (in the prior .grok dir) has the full detailed approved plan with risks, bugfixer context, and 1-7 steps. Use it + this handoff.

Good luck — get us to the north star.

(End of handoff. New session: start by reading this, git status, then a clear launch + attach guidance.)