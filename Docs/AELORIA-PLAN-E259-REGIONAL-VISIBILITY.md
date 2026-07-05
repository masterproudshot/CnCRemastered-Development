# E.2.59 — Late-game regional object invisibility (LAYERS cap fairness)

**Branch:** `experimental`  
**Status:** Implemented in DLL (soak V2 pending; anchor soak `d693a684-49e9`)  
**North star link:** Visible/selectable/orderable units **across full map** for 20–30+ min, not only launch / north band.

## User symptom (evidence)

| Session | Result |
|---------|--------|
| `d693a684-49e9` | Long `-NC` soak: **no crash**, good speed end-to-end; launch visibility OK after E.2.56+58 |
| ~10–15 min in | **Bottom ~⅓ of map:** buildings + units **gone**; **ground + ore/gems still visible** |

**Interpretation:** Sim + terrain/resource overlays OK; **object LAYERS export** (`Get_Layer_State` → 512 `CNCObjectStruct` slots) fails for a **geographic band**, not shroud and not MapGen.

## Root-cause hypotheses (ordered)

1. **512 cap + `Aeloria_TrimDrawCountPreferRetain`** — On trim, pass 1 keeps only `Aeloria_LayersSlotRetainPriority` (tracked starting units + human deployed buildings). Pass 2 fills remainder in **intercept draw order**. Layer walk is **layer index × map iteration order**; southern / late-walk objects are **systematically dropped** when `totalBase + drawCount > 512`.

2. **`total_clamp` final trim** — `TotalObjectCount` clamped to 512 without spatial fairness; tail of export list (often late walk order) discarded wholesale.

3. **Sustain retire / graduate** — Objects hand off to “normal” walk; if walk skips (guards, `IsDown`, unhealthy techno), they **never reappear** in client list while still on `Map.Layer`.

4. **Lower priority** — `BULK_SKIP_INVALID_POS` cluster on southern coords (check in soak log).

## Goals (acceptance)

- G1: Scroll to **bottom third** after 15+ min — **AI + human technos and buildings** visible (same as ground).
- G2: No regression: launch visibility (E.2.56+58), no frame-0 crash (E.2.54), late AV guards (E.2.51).
- G3: `-NC` perf not worse than `d693a684` soak (no per-frame full-map scan unbounded).

## Non-goals

- E.2.60 MCV deploy/control (backlog unless repro returns).
- Raising 512 client cap (Unity contract — retain fairness within cap).
- Terrain / shroud / Unity tile pipeline.

## Implementation plan (PR slices)

### Phase 0 — Forensics (same session + analyzer)

- Locate log for `d693a684-49e9` under `Logs/` or launcher copy path.
- Run `Analyze-AeloriaSoak.ps1 -Profile P4` (and NS if available).
- Grep: `LAYERS_CAP_DROP`, `LAYERS_NEAR_CAP`, `layer_walk_trim`, `total_clamp`, `BULK_POST_COUNT`, `SUSTAIN_BULK`, `LAYER_EXPORT_SKIP`.
- Correlate first sustained `LAYERS_CAP_DROP` / `total_clamp` time with user ~10–15 min wall clock.

**Exit:** RCA bullet in `AELORIA-RCA-SKIRMISH-CRASH-20260702.md` (visibility family E, not AV).

### Phase 1 — Retain priority v2 (DLL)

**File:** `REDALERT/DLLInterface.cpp`

1. Extend `Aeloria_LayersSlotRetainPriority` (or sibling `Aeloria_LayersSlotGeographicRetain`) to score:
   - Human house techno / building (always).
   - Active combat units (optional: `IsSelectable` + on map + not limbo).
   - **Map cell Y band:** e.g. retain minimum quota per vertical third of `Map.CellHeight` when `near_cap` (use `Coord_Cell` / `Cell_Y` from object coord).

2. **`Aeloria_TrimDrawCountPreferRetain`:** When trimming, use **two-pass + quota**:
   - Pass A: priority objects (existing + human + per-band minimum slots).
   - Pass B: fill remaining slots round-robin across Y thirds (or sorted by cell Y) so one band cannot lose 100% of non-priority slots.

3. **`total_clamp`:** Before blind truncate to 512, **sort or select** dropped set to preserve per-band minimum and human-visible set; log `LAYERS_CAP_DROP site=total_clamp_fair` with band stats.

4. Diagnostics: `LAYERS_TRIM_BAND y_third=%d kept=%d dropped=%d frame=%u` (budgeted, quiet-safe prefix).

### Phase 2 — Sustain / walk handoff audit

- When `sustainRetired` or `Aeloria_GraduateTrackedObject`, ensure object still appears in export if on `Map.Layer` and `IsDown` flickers.
- Optional: **late-game sustain lite** for non-graduated AI buildings in southern cells only when `TotalObjectCount >= 480` (budgeted exports).

### Phase 3 — Analyzer + docs

- `Analyze-AeloriaSoak.ps1`: P4/NS checks for `LAYERS_TRIM_BAND`, cap drops per minute, flag if `total_clamp` without prior `NEAR_CAP`.
- `AELORIA-PHASE-E22-PLAN.md` E.2.59 entry; `AELORIA-STATUS-WAVES.md` wave 9 row.

## Verification ladder

| Step | Command / action | Pass |
|------|------------------|------|
| V0 | MSBuild Release Win32 | exit 0 |
| V1 | 5 min skirmish launch | buildings + MCV visible |
| V2 | 20+ min `-NC`, patrol bottom third | technos visible throughout |
| V3 | P4 analyzer | max_frame ≥ 7500, no WER |
| V4 | G-W7b sign-off | user + analyzer |

## Risk / rollback

- **Risk:** Extra retain logic increases CPU near cap — mitigate with quota only when `count >= 480`.
- **Rollback:** Revert to E.2.49 trim only; keep new logs behind `AELORIA_LAYERS_FAIR_TRIM=1` env if needed for A/B.

## Dependencies

- E.2.49 (instrumentation) — landed  
- E.2.56+58 (populate) — landed, soak `d693a684`  
- Blocks: Experimental promote narrative until G1 passes on same map recipe as soak