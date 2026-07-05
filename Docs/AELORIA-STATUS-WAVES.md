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
| 6 | PR 6 B4, PR 7 A5 | pending | map integration |
| 7 | User soak | pending | P4 ≥7500, no WER |

## User gates

- **G-W7a:** After WAVE-5 — 5+ min post-Start (Fix-M1).
- **G-W7b:** After WAVE-6 — 20–30 min `Launch-Aeloria.ps1 -Profile Experimental -NC`, run `Analyze-AeloriaSoak.ps1 -Profile P4`.

## Evidence anchors

| Session | Issue |
|---------|--------|
| `1c4c2d18-c1be` | Late DLL AV `000b7fdf` ~frame 58659 |
| E.2.45–48 | M0 preview gates (landed) |