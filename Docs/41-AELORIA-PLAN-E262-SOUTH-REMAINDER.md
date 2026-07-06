# ~~E.2.62+~~ — **Superseded by E.2.65** (`Docs/AELORIA-PLAN-E265-UNIFORM-CAP.md`)

Do not implement geographic south/decile PRs. Kept for soak history only.

# E.2.62+ — South remainder visibility (post–E.2.61b) [ARCHIVE]

**Branch:** `experimental` @ `aab8eae` (DLL `f7a929e`)  
**Validated soak:** `1f5f201c-7d98` (~33 min wall, **~53k frames**, clean exit, no WER)  
**Prior failure:** `f6af36ce-05b0` (~⅓ south blank @ ~16k frames, crash @ ~61k, **zero** `LAYERS_SLOT_REPLACE`)

## Where we stand (scorecard)

| Goal | Before 61b | After `1f5f201c-7d98` | Status |
|------|------------|------------------------|--------|
| G0 Launch / preview visibility | OK (E.2.56+58) | User: positive session | **PASS** |
| G1 Full-map technos @ 15+ min | ~⅓ south blank | ~**bottom 10%** still blank | **PARTIAL** (major win, not done) |
| G4 No WER / hard crash @ 30+ min | `f6af36ce` crash | No crash; `max_frame ≈ 53k` in log tail | **PASS** (this session) |
| G5 Cap mechanism | Drops only; 1.1M `NEAR_CAP` storm | **26k+** `LAYERS_SLOT_REPLACE`, `mode=draw_it` active | **PASS** (mechanism) |
| 512 client cap | unchanged | unchanged | **constraint** |

**Wave 9 (E.2.59+59b+61+61b):** ship-quality for **stability + replace**; **G1 not closed** until bottom band ≈0% blank on standard 4p soak.

## Log signals (attribution hints)

From `Aeloria-Debug_20260705_015139_1f5f201c-7d98.log`:

- `LAYERS_SLOT_REPLACE` present at scale (vs **0** on `f6af36ce-05b0`) — E.2.59b/61b path is live.
- Many replaces show **`y_third_in=2 y_third_out=2`** — south-in evicts south-out; **does not increase south slot share** on the client list, only swaps which south object owns a slot.
- `LAYERS_TRIM_BAND` near cap: **`y_third=2 kept=4`** vs **`y_third=1 kept=7`** @ ~20k frames — south third still underrepresented in trim/retain histogram.
- **`layer_walk_skip` ~5k** — walk-order / soft-skip still drops objects that never get a replace hook.
- QE **deferred**: no replace on **`foot_sustain` / `preview_safe_emit`** cap returns (still hard-drop).
- **`LAYERS_NEAR_CAP`** still multi-line per frame when `count` steps 480→512 (throttle targets pinned 512, not ramp).

**Working hypothesis for remaining ~10%:** Extreme **south Y decile** (bottom of third 2) + **foot/sustain** export paths + **same-third replace churn** → local starvation while north/mid look healthy.

## North star (unchanged)

4p Experimental skirmish: menus OK; units **visible / selectable / orderable** (human + AI) **full map indefinitely** (no artificial duration caps); full-zoom mods; **no WER**. No frame-1 `LIVE_SKIRMISH_ARMED`. **512 cap** not raised.

---

## Implementation plan (PR DAG)

### PR1 — **E.2.62a** Geographic replace policy @ cap

**File:** `REDALERT/DLLInterface.cpp` (`FindEvictableSlotIndex`, `TryReplaceLayersSlotAtCap`, draw-it replace)

1. When `y_third_in == 2` (or incoming cell in **bottom decile** of map height), prefer evict from **`y_third_out ∈ {0,1}`** first; only `y_third_out=2` if no eligible lower-priority slot elsewhere.
2. Score evict candidates: **lowest** `LayersSlotRetainPriorityV2`, then **farthest from incoming cell Y** within overrepresented third.
3. Log extension (budgeted): `LAYERS_SLOT_REPLACE ... y_decile_in=%d y_decile_out=%d` for soak diff.
4. **Acceptance:** P4 grep shows material share of south admissions with `y_third_out<2`; user bottom-10% improved on 15+ min soak.

**Rollback:** `AELORIA_LAYERS_SLOT_REPLACE=0` (unchanged).

---

### PR2 — **E.2.62b** Replace hooks on sustain / safe-emit

**File:** `DLLInterface.cpp` (foot_sustain, preview_safe_emit, bulk_idx parity)

1. Before cap `return` / drop on **`foot_sustain`** and **`preview_safe_emit`**, call **`TryReplaceLayersSlotAtCap`** then **`LayersReplaceDrawIntoSlotAtCap`** when walk-equivalent draw is required (mirror 61b walk path).
2. On success: **`OnLayersSlotReplaced`** + stab `clientListInserted` (same as 61b).
3. **Acceptance:** Log shows `LAYERS_SLOT_REPLACE site=foot_sustain|preview_safe_emit`; fewer `layer_walk_skip` for southern foot units after 20k frames.

---

### PR3 — **E.2.62c** Bottom-decile retain quota (trim + pinned 512)

**File:** `DLLInterface.cpp` (`TrimDrawCountPreferRetain`, `ClampLayersListFair`, `ReshuffleLayersListAtCap`)

1. Split Y-third 2 into **upper ⅔ of third** vs **bottom decile** (configurable `AELORIA_LAYERS_SOUTH_DECILE=1`).
2. When `count >= 480`, enforce **minimum kept slots** for bottom decile (e.g. ≥ `max(8, total*0.08)` — tune from map size).
3. When **pinned at 512**, run **fair compact** pass (E.2.59 `total_clamp_fair`) on cadence, not only on overflow below cap.
4. Extract shared **`Aeloria_CompactLayersListFairInPlace`** (QE nit) to dedupe reshuffle vs clamp.
5. **Acceptance:** `LAYERS_TRIM_BAND` shows bottom-decile `kept` ≥ quota; G1 user pass.

---

### PR4 — **E.2.63** Cap telemetry + throttle hardening

**Files:** `DLLInterface.cpp`, `Scripts/Analyze-AeloriaSoak.ps1`

1. Extend E.2.61 throttle to **ramp band** 480–512 (`intercept_inc`), not only pinned 512.
2. Aggregate **`LAYERS_SLOT_REPLACE_COUNT`** per 600 frames; log **`LAYERS_SLOT_REPLACE_FAIL reason=all_priority`** (QE Issue 8).
3. Analyzer: compare sessions — replace count, `y_third_out` histogram, first `count==512` frame, `layer_walk_skip` rate post-20k.
4. **Acceptance:** P4 log lines/frame ≪ 104; analyzer one-liner includes replace + skip stats.

---

### PR5 — **E.2.64** Reshuffle cadence (perf guard)

**File:** `DLLInterface.cpp`

1. `ReshuffleLayersListAtCap`: always when `count==512`; else every **N frames** or when band skew > threshold (QE Issue 4).
2. **Acceptance:** No perf regression vs `1f5f201c`; optional frame-time spot check.

---

### Backlog (unchanged)

| ID | Item | Trigger |
|----|------|---------|
| E.2.60 | MCV deploy / control | User repro outside visibility |
| E.2.51+ | Late AV / unhealthy techno | New WER with symbol |
| Client cap raise | — | **Never** without Unity contract change |

---

## Verification ladder (next soak)

| Step | Action | Pass |
|------|--------|------|
| V0 | MSBuild Release Win32 | exit 0 |
| V1 | 5 min preview / launch | MCV + buildings selectable |
| V2 | 15 min | scroll **bottom 10%** — technos visible |
| V3 | 30+ min `-NC` | no WER; `max_frame ≥ 7500` |
| V4 | Analyzer + user sign-off | G1 **PASS** |

```powershell
.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC
.\Scripts\Analyze-AeloriaSoak.ps1 -Profile P3
```

**A/B:** `AELORIA_LAYERS_SLOT_REPLACE=0` only if regressions; keep fair-trim on for attribution.

---

## Suggested execution order

1. **PR1 + PR2** (highest G1 leverage, low risk)  
2. **PR3** (quota — needs tuning from one soak histogram)  
3. **PR4** (ops + gates)  
4. **PR5** (if CPU or log size hurts)

**Docs to update on merge:** `37-AELORIA-PHASE-E22-PLAN.md` (E.2.62–64 entries), `32-AELORIA-STATUS-WAVES.md` wave 9 → **done** when G1 passes, `43-AELORIA-RCA-SKIRMISH-CRASH-20260702.md` visibility family E addendum (`1f5f201c`).