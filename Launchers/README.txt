Project Aeloria - Fast Launchers

These batch files let you launch Red Alert Remastered directly with your mod pre-selected,
bypassing the slow in-game mod menu and multiple restarts.

Usage:
- Double-click the desired .bat file
- The game will launch straight into Red Alert with the chosen profile active

Available Launchers:
- Launch-Aeloria-Stable.bat          → Daily driver (only tested features)
- Launch-Aeloria-Experimental.bat    → New / risky changes
- Launch-Aeloria-Debug.bat           → For Visual Studio debugging (attach after launch)
- Launch-Vanilla-Plus.bat            → Minimal safe baseline for comparison

How it works:
- Uses direct ClientG.exe execution
- steam_appid.txt trick for faster startup
- MOD= parameter auto-selects the correct mod from your Documents folder
- REDALERT skips the game selection screen

Note:
These launchers assume your compiled RedAlert.dll is already placed in the
corresponding folder under Development/Mods/Red_Alert/<Profile>/Data/

After building a new DLL, just copy it into the right Data/ folder and re-launch.
