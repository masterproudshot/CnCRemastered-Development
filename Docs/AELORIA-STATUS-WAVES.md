# Aeloria unified waves — status checklist

**Authoritative plan:** `Docs/AELORIA-NORTHSTAR-UNIFIED-PLAN.md`  
**Branch:** `experimental`  
**Orchestrator:** master agent + implementer/reviewer subagents per PR

## Wave progress

| Wave | PRs | Status | Gate |
|------|-----|--------|------|
| 0 | PR 0 docs | done | docs in repo |
| 1 | PR 1 E.2.50, PR 8 B0 | done | MSBuild |
| 2 | PR 2 E.2.51, PR 9 B1 | done | late-AV symbol notes |
| 3 | PR 3 E.2.49, PR 10 B2 | done | layers instrumentation |
| 4 | PR 4 E.2.52* **skipped**, PR 11 B3 | done | *PR4 skipped; B3 landed |
| 5 | PR 5 C1–C3 | done | analyzer / WER hygiene |
| 6 | PR 6 B4, PR 7 A5 | done | map integration + promote docs |
| 7 | E.2.56+58 populate | done | soak `d693a684` launch visibility OK |
| 8 | User soak (stability/perf) | done | long `-NC`, no crash, good speed |
| 9 | E.2.65 uniform LAYERS cap | **G1 soak pass** `c35496c3-7951` | visibility OK; **perf slow** → wave 10 |
| 10 | E.2.66 perf @ cap | **implemented** — soak pending | cadence reshuffle, ramp log, sustain cache |

## User gates

- **G-W7a:** After WAVE-5 — 5+ min post-Start (Fix-M1).
- **G-W7b:** After WAVE-6 — 20–30 min `Launch-Aeloria.ps1 -Profile Experimental -NC`, run `Analyze-AeloriaSoak.ps1 -Profile P4`.

## Evidence anchors

| Session | Issue |
|---------|--------|
| `d693a684-49e9` | E.2.56+58 pass; late bottom-⅓ **object** invisibility (terrain OK) |
| `1c4c2d18-c1be` | Late DLL AV `000b7fdf` ~frame 58659 |
| E.2.45–48 | M0 preview gates (landed) |