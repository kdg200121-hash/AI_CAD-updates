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

- Version: 1.0.8
- Minimum supported version: 1.0.0
- Release note: Installer now prefers the all-users AutoCAD ApplicationPlugins location when available, preserves the existing bundle location during updates, and guarantees the Seesum AI ribbon tab after AutoCAD 2022 startup.
