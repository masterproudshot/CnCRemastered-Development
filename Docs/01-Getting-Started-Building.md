# Getting Started - Building RedAlert.dll for Project Aeloria

## Prerequisites

- Visual Studio 2017 or 2019 (2017 is most compatible with the original solution)
  - C++ workload
  - MFC/ATL support
  - Windows 8.1 SDK or Windows 10 SDK
- Git (for this repo)

## Recommended: Work from the Cloned Rampastring Base

The source lives at:
`Development/Source/Rampastring-MoreQoL/`

The Red Alert logic is in the `REDALERT/` folder.

The full solution is `CnCRemastered.sln`.

## Build Steps

1. Open `CnCRemastered.sln` in Visual Studio.
2. If prompted, retarget the projects to your installed SDK and toolset (v141 or v142 recommended).
3. In the RedAlert project, add the following preprocessor definition if you get packing mismatch errors:
   `WINDOWS_IGNORE_PACKING_MISMATCH`
4. Set configuration to **Release** and platform to **Win32**.
5. Build the solution (Batch Build → select RedAlert project is often fastest).
6. The compiled `RedAlert.dll` will appear in `bin/` or a similar output folder.

## Installing the DLL for Testing

Copy the built `RedAlert.dll` into:

`Development/Mods/Red_Alert/Aeloria-Experimental/Data/RedAlert.dll`

Then use one of the launchers in `Launchers/`.

## Important Notes

- Only one DLL mod can be active at a time.
- Always test in the Experimental profile first.
- After major changes, consider creating a new "Stable" checkpoint by copying the Experimental DLL + any supporting files into the Stable folder.

## Debugging

Use the `Launch-Aeloria-Debug.bat` launcher. It enables `MOD_DEBUG` and `NO_EVENT_HANDLER`.

After launching, attach Visual Studio:
Debug → Attach to Process → `ClientG.exe`
