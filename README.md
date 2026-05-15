# Project Aeloria

**High-quality Quality of Life mod for Command & Conquer: Red Alert Remastered**

## Philosophy

- Focus on **excellent QoL** that makes the game feel modern and pleasant without changing the core feel of classic Red Alert.
- Prioritize **smart harvesters**, **rally points**, **pathfinding**, camera/zoom improvements, and base-building conveniences.
- Keep the AI relatively predictable and "dumb" (player preference). No super-aggressive AI cheating.
- Full freedom to make deep changes via custom `RedAlert.dll`.
- Strong emphasis on **safety, revertibility, and clean development practices**.

## Project Structure

```
Development/
├── Source/                    # Forked and modified game source (Rampastring More QoL base)
│   └── Rampastring-MoreQoL/   # Original foundation
├── Mods/                      # Packaged, ready-to-use mod folders
│   └── Red_Alert/
│       ├── Aeloria-Stable/
│       ├── Aeloria-Experimental/
│       └── Vanilla-Plus/
├── Launchers/                 # One-click batch files for fast testing
├── Docs/                      # Design documents, change logs, feature specs
├── Scripts/                   # Build + packaging helpers
└── Published/                 # Final builds ready for Steam Workshop or distribution
```

## Fast Testing Workflow (The Big Improvement)

Instead of the painful Steam → Options → Mods → Restart loop, use the launchers in `Launchers/`.

These use direct `ClientG.exe` execution with command-line arguments for dramatically faster iteration.

## Getting Started (Development)

1. Clone this repo
2. Build `RedAlert.dll` from `Source/Rampastring-MoreQoL/REDALERT` using Visual Studio 2017/2019
3. Place compiled DLL into the appropriate mod folder under `Mods/Red_Alert/Aeloria-*/Data/`
4. Use a launcher from `Launchers/` to test quickly

## Mod Profiles

- **Aeloria-Stable** — Daily driver. Only well-tested features.
- **Aeloria-Experimental** — New ideas and risky changes live here.
- **Vanilla-Plus** — Minimal safe baseline (easy rollback target).

## License

This project builds upon Rampastring's "More QoL Improvements" (based on the official EA-released CnC Remastered source code under GPL-3.0).

All original contributions in Project Aeloria are also GPL-3.0.

## Author

Jackson — Project Aeloria (2026)
