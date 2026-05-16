Project Aeloria - Launchers (Updated Version)

These batch files now use the recommended method of launching through Steam itself.
This is more reliable than directly running ClientG.exe.

How to use:
- Double-click the .bat file you want to run.
- Steam will launch Red Alert with the selected mod automatically.

Available Launchers:
- Launch-Aeloria-Experimental.bat   → For testing new changes
- Launch-Aeloria-Stable.bat         → Your main daily driver
- Launch-Vanilla-Plus.bat           → Clean baseline for comparison
- Launch-Aeloria-Debug.bat          → For attaching debuggers (MOD_DEBUG enabled)

Important:
- Steam must be running (or it will start automatically).
- Make sure your mod folder exists in:
  Development/Mods/Red_Alert/[ModName]/
  with a Data/RedAlert.dll inside it.

Customizing:
If your Steam is installed in a different location, edit the STEAM_EXE line in the .bat file.

Example:
set STEAM_EXE="D:\Steam\steam.exe"
