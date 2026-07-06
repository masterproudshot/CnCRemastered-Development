# Aeloria compact handoff (`/compact`)

**Full handoff:** `Docs/AELORIA-PROJECT-HANDOFF.md`

**Branch:** `experimental` (uncommitted fixes post-edc270e) · **DLL:** Experimental profile (just built+deployed)

## North star

4p+ Experimental skirmish: menus OK, units **visible / selectable / orderable** (human + AI) **indefinitely** on modern hardware (no hard time limits; `max_frame` numbers are debug/test milestones only), full-zoom mods, **no WER**. **512 client cap** unchanged — not literal “every sim unit at once.”

## Latest soak (user: ~45m then slow+crash; launcher run to ~94k frame / ~1hr)

- Reached frame 93984; launcher saw **no crash zip** for session (progress vs prior 45m crash).
- End: heavy `LAYERS_NEAR_CAP` (480/512), flood `LAYER_EXPORT_SKIP unsafe_layer_obj`, `LATE_GAME_AV_GUARD shadow_obj_stale`, cap drops. Log file ballooned (~989MB).
- Polish/smooth noted early/mid; slowdown last 5-10m + exit. Index bloat + full walks + guard spam suspected.
- **New bug report:** MiGs (and aircraft) invisible in flight.

## Just landed (decisive fixes for visibility + bloat)

- Aircraft **always bypass** candidate/early-skip in Get_Layer_State (M2.2 view cull was dropping air anywhere; 0-500 cell proto was broken).
- Widened QueryBestCandidates (full-map scan capped at 400) + high prio for RTTI_AIRCRAFT.
- Relaxed aircraft defer in DLL_Draw_Intercept when live LAYERS export (allow virtual even pre-MAIN cache; jets not just rotors).
- Broadened `Aeloria_ForceLayerExport` for all aircraft.
- `g_AeloriaWorldIndex.Clear()` each export (prevents heap/bucket growth from dead objs across frames — root of late slowdown).
- Rebuilt + deployed to Aeloria-Experimental.

## Landed before (E series)

E.2.65 uniform cap · E.2.61b replace · E.2.66 perf cadence + WorldIndex proto

## Next (build/test)

- Re-soak 4p Experimental long (Launch... -NC); verify MiGs visible in flight whole game, flat perf, no crash.
- Tighten further (event-driven index updates for true O(view) not O(total) walk; reduce guard spam at cap; metrics).
- Update 70-MultiAgent... and plans after soak data.

```powershell
.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC
# or use Launch-Aeloria-Experimental.bat
```