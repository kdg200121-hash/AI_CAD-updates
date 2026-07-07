# AI_CAD Updates

Release artifacts for Seesum AI AutoCAD add-in.

## Install

Run `SeesumAI_AutoCAD_Installer.exe`.

PowerShell fallback:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-latest.ps1
```

## Files

- `version.json`: current version metadata
- `SeesumAI_AutoCAD_Installer.exe`: Windows installer
- `SeesumAI.bundle.zip`: AutoCAD ApplicationPlugins bundle package
- `install-latest.ps1`: installer/updater

## Current Release

- Version: 1.0.5
- Minimum supported version: 1.0.0
- Release note: Fix installer access denied by running the updater from temp and falling back to in-place bundle updates when backup move is blocked.
