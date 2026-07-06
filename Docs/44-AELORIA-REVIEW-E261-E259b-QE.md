# QE Code Review — E.2.61 + E.2.59b (`092313f` → `ea0b68d`)

**Reviewer:** Quality engineering pass (orchestrator; subagent coordinator unavailable)  
**Scope:** `REDALERT/DLLInterface.cpp`, `Analyze-AeloriaSoak.ps1`, phase/wave/RCA docs  
**Verdict:** **Ship with fixes** — soak-worthy for validation, but address **2 major** items before calling G1/G4 done.

**Update (E.2.61b `f7a929e`):** Major bugs 1–3 patched — see `Docs/33-AELORIA-COMPACT-HANDOFF.md`.

---

## Summary

The change correctly targets the real failure mode from `f6af36ce-05b0`: admission at **512** (not overflow trim). Slot replace + per-export reshuffle are the right shape; E.2.61 log throttling should cut megabyte-scale log storms. Main risks are **preview-path regression** from `StripUnsafeDrawSlots` using strict `IsExportSafeObjectPtr`, **bulk-only replace** skipping full intercept draw (complex technos), and **missing replace hooks** on `foot_sustain` / `preview_safe_emit`. Reshuffle at every export for `count ≥ 480` is correct but hot — monitor frame time in soak.

---

## Issues

### Issue 1 — Severity: bug
- **File:** `DLLInterface.cpp` (~6536–6555, call site ~8806)
- **Description:** `Aeloria_StripUnsafeDrawSlots` runs after **every** `Draw_It` batch (including **preview** skirmish) and drops slots where `!Aeloria_IsExportSafeObjectPtr`. Preview populate (E.2.56) intentionally admits wider ptrs than export-safe; intercept may fill slots that strip then removes → **invisible human/MCV/buildings** in preview.
- **Suggestion:** Gate strip with `!previewLayerWalk` (pass flag into helper), or retain slots that pass `Aeloria_IsLayerPopulateObjectPtr` / `Aeloria_LayersSlotRetainPriorityV2`.
- **Status:** open

### Issue 2 — Severity: bug
- **File:** `DLLInterface.cpp` (~6443–6469, ~8681–8684, bulk replace ~8875)
- **Description:** `Aeloria_TryReplaceLayersSlotAtCap` only uses `Aeloria_PopulateEarlyBulkSlot`, not full `DLL_Draw_Intercept` population. Walk/bulk replace then `continue` **without** `Draw_It` — factories, multi-sprite buildings, and tethered queue visuals may be wrong or flat vs intercept path.
- **Suggestion:** For replace-at-walk, consider `Draw_It` with a temporary “replace index” intercept mode, or restrict replace to infantry/vehicles until intercept-fill helper is shared. At minimum, log/asset-verify on WF/MCV after replace in soak.
- **Status:** open

### Issue 3 — Severity: bug
- **File:** `DLLInterface.cpp` (~8875–8880, sustain/preview bulk)
- **Description:** Replace success on bulk/sustain paths `continue`s without updating `stab.clientListInserted`, `bulkAdded`, or `Aeloria_FindObjectExportIndex` coherence — tracking map may think object never exported while slot shows it (or vice versa after eviction).
- **Suggestion:** On successful replace, set `clientListInserted` on stab if present; call `Aeloria_FindObjectExportIndex` before replace to update existing slot only when same ptr.
- **Status:** open

### Issue 4 — Severity: suggestion
- **File:** `DLLInterface.cpp` (~6472–6533)
- **Description:** `Aeloria_ReshuffleLayersListAtCap` runs on **every** `Get_Layer_State` when `480 ≤ count ≤ 512` — full `memcpy` of hundreds of `CNCObjectStruct` per export. Under 1M+ near-cap exports (prior soak), this could add measurable CPU even with thinner logs.
- **Suggestion:** Reshuffle on cadence (e.g. `Frame % 15 == 0` or when histogram skew exceeds threshold), not every export; always reshuffle when `count == 512`.
- **Status:** open

### Issue 5 — Severity: suggestion
- **File:** `DLLInterface.cpp` (~6371–6384, ~6463–6468)
- **Description:** `LAYERS_SLOT_REPLACE` logs **once per frame** (`s_lastReplaceLogFrame`), hiding volume metrics for P4 “non-zero replace under cap” acceptance.
- **Suggestion:** Budgeted counter log every N replaces or aggregate `LAYERS_SLOT_REPLACE_COUNT` in `BULK_POST_COUNT` cadence.
- **Status:** open

### Issue 6 — Severity: suggestion
- **File:** `DLLInterface.cpp` (~8142, ~8371+)
- **Description:** Plan listed `preview_safe_emit` and `foot_sustain` replace hooks; not implemented — foot units and preview safe emit still hard-drop at cap.
- **Suggestion:** Add `TryReplaceLayersSlotAtCap` before `foot_sustain` / `preview_safe_emit` cap returns (same pattern as `bulk_idx`).
- **Status:** open

### Issue 7 — Severity: nit
- **File:** `DLLInterface.cpp` (~6282–6368 vs ~6472–6533)
- **Description:** Near-duplicate fair compaction logic in `Aeloria_ClampLayersListFair` and `Aeloria_ReshuffleLayersListAtCap`.
- **Suggestion:** Extract `Aeloria_CompactLayersListFairInPlace(list, count)` shared by both.
- **Status:** open

### Issue 8 — Severity: nit
- **File:** `DLLInterface.cpp` (~6402–6440)
- **Description:** If **all** 512 slots are `RetainPriorityV2`, `FindEvictableSlotIndex` returns -1 — southern band stays starved with no metric.
- **Suggestion:** Budgeted log `LAYERS_SLOT_REPLACE_FAIL reason=all_priority` once per minute.
- **Status:** open

---

## Positive findings

- `TryReplace` correctly requires `count >= 512` — avoids bogus replace when list not full.
- Intercept guard tries replace **before** drop — correct hook order.
- E.2.61 cap-drop log budget (2/frame) + pinned near-cap cadence (600 frames) directly addresses `f6af36ce` log storm.
- `Aeloria_GuardLayerPopulateObjectPtr` still blocks replace on unsafe incoming ptr.
- Env flags (`AELORIA_LAYERS_SLOT_REPLACE`, `FAIL_CLOSED`, `FAIR_TRIM`) give rollback paths.

---

## Test recommendations

| Priority | Test |
|----------|------|
| P0 | 5 min **preview** `-NC`: human MCV + buildings selectable (catch Issue 1) |
| P0 | 15 min patrol bottom third — compare to pre-59b blanking |
| P1 | 30+ min stability; P4 on log — `LAYERS_NEAR_CAP` lines ≪ 1M, `slot_replace > 0` after frame 16459 |
| P1 | Place WF + produced tank in south after 20 min — visual sanity (Issue 2) |
| P2 | Temporarily `AELORIA_LAYERS_SLOT_REPLACE=0` / `FAIL_CLOSED=0` A-B for attribution |

---

## Issue counts

| Severity | Count |
|----------|------:|
| bug | 3 |
| suggestion | 3 |
| nit | 2 |