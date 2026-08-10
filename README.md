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

- Version: 1.1.7
- Minimum supported version: 1.0.0
- Release note: BTE 안내 한글 복구 및 좌표·회전값 소수점 반올림
