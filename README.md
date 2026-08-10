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

- Version: 1.1.6
- Minimum supported version: 1.0.0
- Release note: PCC 이전 안정 버전 복원 및 BTE 최신 한글 프롬프트 반영
