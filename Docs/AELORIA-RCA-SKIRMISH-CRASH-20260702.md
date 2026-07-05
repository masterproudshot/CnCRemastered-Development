# RCA — Custom skirmish launch crashes (2026-07-02)

**Status:** Active — E.2.45 in tree (preview prune wipe)  
**Evidence logs:** `fa46d5de-8a53` (frame **2426**), `b7e7105c-aa54` (frame **48**), `5f1f8c7f-ff87` (frame **26**), `56d04f08-a76e` (frame **18**, `creation=11` preview prune)

---

## North star requirements (authoritative)

From `Docs/AELORIA-STATUS-20260620.md` and `Scripts/Analyze-AeloriaSoak.ps1`:

| Gate | Requirement |
|------|-------------|
| **Play** | Launch → **custom 4p skirmish** → units **visible, selectable, orderable** (human + AI) |
| **Duration** | **20–30+ minutes** sim time (`max_frame ≥ 7500` on P3/P4) |
| **Stability** | No abrupt log tail, no `REDALERT.DLL` / `VCRUNTIME140` AV |
| **Mods** | Full-zoom / Experimental profile active (`Launch-Aeloria.ps1 -Profile Experimental`) |
| **Blocked** | Map generation until stability sign-off |

**Not S1/S2 labels** — operational gates are **P1** (5 min), **P4** (soak), **G4** (20+ min, E.2.2 plan).

**Daily driver (user):** `Launch-Aeloria.ps1 -Profile Experimental`; map gen blocked until soak PASS.

---

## Symptom summary

| Session | Max frame | When | User-visible |
|---------|-----------|------|----------------|
| `fa46d5de` | 2426 | ~40s lobby preview then Start transition | Crash ~1s after Start |
| `d4b0fef6` | 24 | E.2.40 frame-1 `LIVE_SKIRMISH_ARMED` | Invisibility / early crash |
| `b7e7105c` | 48 | E.2.41 (no frame-1 arm) | Crash during launch / first minute |
| `5f1f8c7f` | 26 | E.2.42 deployed | `Unit guard passed` 2TNK → `Techno_Draw_Object` (PREVIEW, no live arm) |
| `885446a6-f040` | 4135 | E.2.45 | Preview `DEAD_TRACKING_PRUNED creation=11` @0; MCV `Unit guard passed` @3159 (PREVIEW, no live arm) |
| `3f9170a1-e136` | 283 | E.2.46 smoke | M0 lifecycle gates PASS; tail `CC_Draw_Shape` RTTI=5 `at+8=0xffffff00` (family B) |
| `1c4c2d18-c1be` | 58659 | E.2.47–48, non-debug soak ~34 min | WER `REDALERT.DLL` `c0000005` offset **`000b7fdf`**; log ends without `SESSION_END` (family D — late game) |
| `f6af36ce-05b0` | 61214 | E.2.59 soak ~35 min debug | WER `InstanceServerG`; **6.4M** log lines, **1.1M** `LAYERS_NEAR_CAP` pinned @512; abrupt tail (family F) |

**E.2.47–E.2.48 (experimental):** preview building bad+8 placeholder; preview starting-unit legacy MAIN block after creation prune + unhealthy Class belt.

**E.2.51 (in tree):** late-game AV at `DLL+0x000b7fdf` — symbolized to **`TechnoClass::Techno_Draw_Object`** (`TECHNO.obj`, RVA `+0x2f` from `0001:000b7fb0` per `bin/Win32/RedAlert.map`). Trigger: `Get_Layer_State` layer walk → `Draw_It` → MAIN blitter on pool-reused techno with stale `Class`/`+8` after `TRACKING_PRUNE` at scale (~frame 58659, session `1c4c2d18-c1be`). **Fix:** budgeted `LATE_GAME_AV_GUARD` + `Aeloria_GuardExportObjectPtr` on bulk/sustain/factory/export slots; `Aeloria_TechnoClassRawIsHealthy` gate before `Draw_It`; strengthened 512-cap logging.

**E.2.52 (skipped — conditional PR 4):** No Start-transition repro after E.2.47–E.2.51 soak/evidence. Post-E.2.45–48 sessions did not reproduce failure mode A (`fa46d5de` @ frame **2426**); the blocking late crash was family D at ~**58k** frames (`1c4c2d18-c1be`), addressed by E.2.51. Start/@2426 hardening deferred — no DLL change unless a fresh Start-transition repro appears.

North star: **0 / 7** recent sessions pass P4.

---

## Root cause (systemic)

Custom skirmish uses **three coupled subsystems** that were toggled in opposition:

1. **Remastered LAYERS client** — needs `DLL_Draw_Intercept` to fill `CNCObjectStruct` slots (`Get_Layer_State` → `Draw_It` → intercept).
2. **Aeloria early-object hardening** — creation map, +8 guards, bulk/sustain, techno HUD fill.
3. **Skirmish lifecycle** — Unity often **does not** call `CNC_Start_Mission_Timer` while `GameActive` (E.2.39); lobby sim runs **hundreds–thousands of frames** before **Start**.

We tried to fix crashes by **gating all intercept work** on `Aeloria_MatchLayerExportAllowed()` (live match armed). That gate is **false** until mission timer / explicit live → **total invisibility** (E.2.39).

We then **re-opened populate** via `Aeloria_ClientLayerPopulateAllowed()` but **armed live at frame 1** (`Advance_glyphx_skirmish_sim`) → full bulk/HUD for entire lobby → **2426 building AV** (E.2.40).

E.2.41 **removed frame-1 arm** and tied live arm to **`CNC_Start_Mission_Timer`** (+ pending queue). Visibility restored; **sub-minute AV** remains on **starting units** hitting legacy `Techno_Draw_Object` before true MAIN safety (E.2.42).

### Failure mode A — frame ~2426 (`fa46d5de`)

- Long **preview** sim; **no** `LIVE_SKIRMISH_ARMED` / `CNC_Start_Mission_Timer` in log.
- Heavy `CLIENT_DRAW_INTERCEPT` on **RTTI_BUILDING (5)**, `stab=0`, under construction.
- Abrupt tail during building/infantry intercept storm at **frame 2426**.
- **Cause:** Preview path ran **full** client slot population (unsafe techno HUD / building fields) without live-match discipline; Start transition did not arm match via timer API.

### Failure mode B — frame ~48 (`b7e7105c`)

- `PREVIEW_LAYER_EXPORT` only; **no** live arm (E.2.41 correct).
- `BULK_POST_COUNT finalCount=22` at frame 0 from **normal layer walk + intercept** (not complementary bulk — `cur_from_bulk=0`).
- Starting **1TNK** `0DCE435E`: `UNIT_MAIN_GUARD` @ frame 0 → **`Unit guard passed`** @ frame 48 → `Techno_Draw_Object` → log ends.
- **Cause:** Starting unit **graduated off MAIN guard** while `Class`/pool state still unsafe (`+8` can flicker plausible). `IsEarlyStartingUnitMainGuarded` clears when `Aeloria_HasValidMainDrawCache` is true, but cache can be set without **healthy `TechnoClass` raw** or **sane MAIN coords**.

### Failure mode C — frame-1 live arm (`d4b0fef6`)

- `LIVE_SKIRMISH_ARMED via Advance_glyphx_skirmish_sim frame=1`.
- **Cause:** Treating lobby as live match; violates lifecycle model (fixed in E.2.41).

### Failure mode E — late-game regional object invisibility (`d693a684-49e9`, E.2.59)

- Long `-NC` soak after E.2.56+58: **no crash**, launch visibility OK, good perf.
- ~10–15 min wall clock: **bottom ~⅓** of map — **buildings + units invisible**; **ground + ore/gems still visible**.
- **Cause (hypothesis):** `Get_Layer_State` fills ≤512 `CNCObjectStruct` slots; `Aeloria_TrimDrawCountPreferRetain`, blind `total_clamp`, and `layer_walk_skip` at cap drop **late layer-walk / southern-band** objects from the client list while sim + terrain paths continue.
- **Fix (E.2.59):** `Aeloria_LayersSlotRetainPriorityV2`, Y-third quota trim when `count ≥ 480`, `Aeloria_ClampLayersListFair` (`total_clamp_fair`), soft `layer_walk_skip` for underrepresented bands; `LAYERS_TRIM_BAND` diagnostics.
- **Forensics:** soak log `d693a684-49e9` not located under `Logs/` at plan time — correlate `LAYERS_CAP_DROP` / `total_clamp` on next repro.

### Failure mode F — late soak log flood + cap stall (`f6af36ce-05b0`, E.2.59 → E.2.61+59b)

- Debug soak ~35 min wall; log ends abruptly at frame **61214** without `SESSION_END`.
- WER: `InstanceServerG.exe` crash archive captured; no `REDALERT.DLL` offset in analyzer gate.
- **6,397,303** log lines (**104.5** lines/frame); **1,116,141** `LAYERS_NEAR_CAP` events with `maxCount=512` pinned; **404,587** `LAYERS_CAP_DROP` (mostly `layer_walk_skip` / `intercept_guard`); **zero** `LAYERS_SLOT_REPLACE`.
- Tail @61214: ramp `intercept_inc` 502→512 then burst cap drops — list full, no slot recycling for underrepresented bands.
- **Cause:** E.2.59 fair trim reduced blind `total_clamp` but did not **replace** slots at cap; per-step `LAYERS_NEAR_CAP` logging at 512 saturated debug I/O; unsafe ptrs could still populate draw tail before `Draw_It`.
- **Fix (E.2.61):** pin-at-512 log throttle (≤1/600 frames unless count changes); cap-drop budget 2/frame; `Aeloria_LayersFailClosedEnabled` strips unsafe draw slots + `fail_closed_pre_draw` on walk.
- **Fix (E.2.59b):** `Aeloria_TryReplaceLayersSlotAtCap` + reshuffle; `LAYERS_SLOT_REPLACE` diagnostics; rollback env `AELORIA_LAYERS_SLOT_REPLACE=0`.

### Failure mode D — late game ~58k frames (`1c4c2d18-c1be`, E.2.51)

- Non-debug soak ~34 min; log ends without `SESSION_END` at frame **58659**.
- WER: `REDALERT.DLL` `c0000005` fault offset **`000b7fdf`**.
- **Symbol (Release x86 map):** `TechnoClass::Techno_Draw_Object` — `0001:000b7fb0` + `0x2f` → `0001:000b7fdf` (`TECHNO.obj`).
- **Cause:** `Aeloria_PruneStaleTracking` / aggressive cap prune drops stab/creation rows while `Map.Layer` still walks active technos; `Get_Layer_State` calls `Draw_It` → `Techno_Draw_Object` on pool-reused object with corrupt `Class`/`+8`. Bulk/sustain/factory export slots can retain stale `CNCInternalObjectPointer` values under the same race.
- **Fix (E.2.51):** `LATE_GAME_AV_GUARD` (budget 32, critical log); `Aeloria_GuardExportObjectPtr` on intercept/bulk/sustain/factory/shadow paths; `Aeloria_TechnoClassRawIsHealthy` before `Draw_It`; 512-cap bounds logging at intercept (~6019) and layer walk (~7558).

---

## Real fix — skirmish lifecycle model (E.2.42+)

### Phase diagram

```
[Map load] CNC_Start_Custom_Instance
     → PREVIEW: ClientLayerPopulateAllowed == true
     → LIVE_ARMED == false (no bulk, no EnsureStability reseed, no full techno HUD)

[User Start] CNC_Start_Mission_Timer (or PENDING applied on Advance)
     → g_AeloriaUserRequestedLiveStart
     → Aeloria_BeginLiveSkirmishMatch (once)
     → LIVE: MatchLayerExportAllowed == true (bulk, sustain, HUD with SafeForFullTechno)
```

### Code rules (must all hold)

| Path | PREVIEW | LIVE |
|------|---------|------|
| `Aeloria_ClientLayerPopulateAllowed` | ✓ | ✓ |
| `Aeloria_MatchLayerExportAllowed` (bulk/sustain/reseed) | ✗ | ✓ |
| `Aeloria_PopulateTechnoHudFields` / `OverrideDisplayName` | ✗ | ✓ ( + `Aeloria_SafeForFullTechnoLayerFill`) |
| `Advance_glyphx_skirmish_sim` / frame-1 arm | ✗ | **removed E.2.41** |
| Live arm triggers | — | Timer API, pending timer, `Advance_user_skirmish_start` |

### E.2.42 — Starting unit MAIN graduation (partial)

**Problem:** `Unit guard passed` → legacy blitter AV on tracked Unlimbo units.

**Fix (partial):** `TechnoClassRawIsHealthy` only — **not sufficient** (`5f1f8c7f`: Class.Raw=2 healthy, `at+8=0x78417800` still AV @ frame 26).

### E.2.43 — PREVIEW vs LIVE legacy MAIN (implement)

**Problem:** `IsEarlyStartingUnitMainGuarded` cleared when `HasSaneMainDrawCache` from intercept during **PREVIEW** (`PREVIEW_LAYER_EXPORT`, no `LIVE_SKIRMISH_ARMED`).

**Fix:**

- `Aeloria_IsExplicitLiveSkirmishMatch()` — same gate as `Aeloria_MatchLayerExportAllowed`.
- `IsEarlyStartingUnitMainGuarded`: tracked starting units stay guarded if sane cache but **not** explicit live match.
- `UNIT.CPP` / `VESSEL.CPP`: tracked starting units legacy MAIN only when **live match** AND sane MAIN cache AND `TechnoClassRawIsHealthy` AND plausible `+8`.

**Acceptance:** No `Unit guard passed` on tracked units before `LIVE_SKIRMISH_ARMED`; soak P1 **no abrupt tail**; P4 `max_frame ≥ 7500` after custom 4p **Start**.

### Verification commands

```powershell
Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC -DebugMode
# Play: custom skirmish → Start → 5+ min
Scripts\Analyze-AeloriaSoak.ps1 -Profile P1 -DebugLog Logs\Aeloria-Debug_<newest>.log
```

**Pass criteria:** `LIVE_SKIRMISH_ARMED via Advance_user_skirmish_start` or `PENDING_MISSION_TIMER_APPLIED`; **no** `Advance_glyphx_skirmish_sim`; `max_frame ≥ 7500`; `no_abrupt_tail`.

---

## E.2.52 — Start transition hardening (skipped)

**Status:** Skipped (conditional PR 4, 2026-07-04).

| Check | Result |
|-------|--------|
| Repro after E.2.47–E.2.51? | **No** — no session tail at Start/@2426 |
| Dominant late evidence? | **Yes** — `1c4c2d18-c1be` @ frame **58659** (family D) |
| E.2.51 covers family D? | **Yes** — `LATE_GAME_AV_GUARD` + export guards + `TechnoClassRawIsHealthy` |
| DLL change required? | **No** — no obvious gap without Start-transition repro |

**Rationale:** PR 4 was conditional on a fresh Start-transition crash. Soak and post-E.2.45–48 evidence point at late-game AV (~58k), not lobby→Start @2426. Re-open E.2.52 only if a new log shows abrupt tail at Start with `PREVIEW_LAYER_EXPORT` storm and **no** `LIVE_SKIRMISH_ARMED`.

---

## What we are not doing yet

- Map generation (blocked per north star).
- E.2.2 VFX soak promotion until G4 PASS returns.
- Declaring victory on &lt;5 min or lobby-only logs.
- E.2.52 Start hardening (skipped until repro).