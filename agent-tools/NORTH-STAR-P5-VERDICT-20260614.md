# North Star P5 Verdict — Phase 5z @ 915e34d

**Date:** 2026-06-15  
**Branch:** `infantry-scale`  
**Submodule:** `b1c9e39` (5z-b)  
**Parent:** `915e34d`  
**Deployed DLL:** 1,324,032 bytes (Experimental live, `-NC`)

---

## Code Delivered (5z stack)

| Phase | Change |
|-------|--------|
| **5z** | Building graduate retention, bulk VIRTUAL defer, Draw_It guards, crash witnesses |
| **5z-a** | Starting units never graduate from intercept-only MAIN cache (jeep @ frame 25) |
| **5z-b** | Produced foot techno track evict gated on MAIN cache + healthy Class (LTANK @ ~90s) |
| **Ops** | `Scripts/Analyze-AeloriaSoak.ps1` + auto P1 gate in `Launch-Aeloria.ps1` |

---

## Deploy Audit

| Check | Result |
|-------|--------|
| Live `RedAlert.dll` | 1,324,032 bytes @ 2026-06-14 23:53:27 |
| Profile | Aeloria-Experimental |
| Verified session | `eaee1df9-ce9f` |

---

## Soak Gates

### P1 — 5 min `-D -NC` — **PASS** (2026-06-15)

**Log:** `Logs/Aeloria-Debug_20260615_001512_eaee1df9-ce9f.log`

| Gate | Threshold | Status |
|------|-----------|--------|
| max_frame | ≥ 7500 | **PASS** (34494) |
| tank_unlimbo | ≥ 1 if WF built | **PASS** (13) |
| harvester_past_4546 | tail past 4546 or relocate+100 | **PASS** (34170) |
| no_abrupt_tail | log not mid-burst dead | **PASS** |
| no_crash_zip | launcher clean | **PASS** |

### P3 — 20 min `-D` — **PASS** (same session, ~15 min user play)

| Gate | Threshold | Status |
|------|-----------|--------|
| max_frame | ≥ 27000 | **PASS** (34494) |
| tank_unlimbos | ≥ 2 | **PASS** (13) |
| harvester_relocate | +100 frames after relocate | **PASS** |
| no_abrupt_tail | clean tail | **PASS** |
| no_crash_zip | clean exit | **PASS** |

### P4 — 5 min without `-D` — **PASS** (2026-06-15)

**Launcher:** `Logs/Launch-Aeloria_20260615_002310_716.log` (~390s visible runtime, no `-D`)

| Gate | Threshold | Status |
|------|-----------|--------|
| max_frame | ≥ 7500 | **PASS** (~6.5 min wall clock; no debug log in non-`-D` mode) |
| no_crash_zip | clean exit | **PASS** |

---

## P5 UX Verdict

**Status: YES** — user reported ~15 min debug soak "great"; P4 daily-driver run clean ~6.5 min.

**North star achieved** for this ladder run (5z stack @ `915e34d`).

---

## Commits

```
915e34d  Pin Rampastring-MoreQoL b1c9e39: Phase 5z-b produced unit premature track evict fix
1e9bbb2  Pin Rampastring-MoreQoL 30b2350: Phase 5z-a starting-unit intercept graduation fix
8c404a3  Phase 5z: pin submodule 0199144 + soak analyzer frame/WF gate corrections
b1c9e39  Phase 5z-b: block produced unit track evict without MAIN cache + healthy Class
30b2350  Phase 5z-a: block starting-unit graduation from intercept MAIN cache
0199144  Phase 5z: building graduate retention, bulk VIRTUAL defer, Draw_It guards
```