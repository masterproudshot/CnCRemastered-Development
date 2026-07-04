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

**E.2.47–E.2.48 (experimental):** preview building bad+8 placeholder; preview starting-unit legacy MAIN block after creation prune + unhealthy Class belt.

North star: **0 / 6** recent sessions pass P4.

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

## What we are not doing yet

- Map generation (blocked per north star).
- E.2.2 VFX soak promotion until G4 PASS returns.
- Declaring victory on &lt;5 min or lobby-only logs.