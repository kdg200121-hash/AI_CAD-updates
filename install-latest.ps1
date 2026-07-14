param(
    [string]$VersionJsonUrl = "https://raw.githubusercontent.com/kdg200121-hash/AI_CAD-updates/main/version.json",
    [string]$PackageUrl,
    [string]$LocalPackagePath,
    [string]$TargetBundleName = "SeesumAI.bundle",
    [string]$TargetPluginsRoot,
    [int]$AutoCADPid = 0,
    [switch]$StartedFromAutoCAD,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:Form = $null
$script:StatusLabel = $null
$script:DetailLabel = $null
$script:ProgressBar = $null
$script:PercentLabel = $null
$script:CloseButton = $null

function Initialize-InstallerWindow {
    if ($NonInteractive) {
        return
    }
    $script:Form = New-Object System.Windows.Forms.Form
    $script:Form.Text = "Seesum AI AutoCAD Update"
    $script:Form.Width = 500
    $script:Form.Height = 250
    $script:Form.StartPosition = "CenterScreen"
    $script:Form.FormBorderStyle = "FixedDialog"
    $script:Form.MaximizeBox = $false
    $script:Form.MinimizeBox = $false
    $script:Form.TopMost = $true

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Seesum AI AutoCAD Update"
    $title.Left = 20
    $title.Top = 18
    $title.Width = 440
    $title.Height = 28
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $script:Form.Controls.Add($title)

    $script:StatusLabel = New-Object System.Windows.Forms.Label
    $script:StatusLabel.Text = "Preparing update..."
    $script:StatusLabel.Left = 20
    $script:StatusLabel.Top = 58
    $script:StatusLabel.Width = 440
    $script:StatusLabel.Height = 24
    $script:StatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $script:Form.Controls.Add($script:StatusLabel)

    $script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
    $script:ProgressBar.Left = 20
    $script:ProgressBar.Top = 92
    $script:ProgressBar.Width = 385
    $script:ProgressBar.Height = 18
    $script:ProgressBar.Minimum = 0
    $script:ProgressBar.Maximum = 100
    $script:Form.Controls.Add($script:ProgressBar)

    $script:PercentLabel = New-Object System.Windows.Forms.Label
    $script:PercentLabel.Text = "0%"
    $script:PercentLabel.Left = 415
    $script:PercentLabel.Top = 89
    $script:PercentLabel.Width = 50
    $script:PercentLabel.Height = 24
    $script:PercentLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $script:Form.Controls.Add($script:PercentLabel)

    $script:DetailLabel = New-Object System.Windows.Forms.Label
    $script:DetailLabel.Text = ""
    $script:DetailLabel.Left = 20
    $script:DetailLabel.Top = 124
    $script:DetailLabel.Width = 440
    $script:DetailLabel.Height = 46
    $script:DetailLabel.ForeColor = [System.Drawing.Color]::FromArgb(71, 85, 105)
    $script:Form.Controls.Add($script:DetailLabel)

    $script:CloseButton = New-Object System.Windows.Forms.Button
    $script:CloseButton.Text = "Close"
    $script:CloseButton.Left = 365
    $script:CloseButton.Top = 175
    $script:CloseButton.Width = 95
    $script:CloseButton.Height = 30
    $script:CloseButton.Enabled = $false
    $script:CloseButton.Add_Click({ $script:Form.Close() })
    $script:Form.Controls.Add($script:CloseButton)

    $script:Form.Show()
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-InstallerProgress {
    param(
        [string]$Status,
        [int]$Percent,
        [string]$Detail = ""
    )

    if (-not $script:Form) {
        return
    }

    $bounded = [Math]::Max(0, [Math]::Min(100, $Percent))
    $script:StatusLabel.Text = $Status
    $script:ProgressBar.Value = $bounded
    $script:PercentLabel.Text = "$bounded%"
    $script:DetailLabel.Text = $Detail
    [System.Windows.Forms.Application]::DoEvents()
}

function Complete-InstallerWindow {
    param(
        [string]$Status,
        [string]$Detail,
        [bool]$Failed = $false
    )

    if ($NonInteractive) {
        Write-Host "$Status $Detail"
        return
    }

    Set-InstallerProgress -Status $Status -Percent 100 -Detail $Detail
    if ($Failed) {
        $script:StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
    }
    else {
        $script:StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
    }

    $script:CloseButton.Enabled = $true
    $script:Form.TopMost = $false
    while ($script:Form.Visible) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
    }
}

function Read-VersionInfo {
    param([string]$Url)

    Set-InstallerProgress -Status "Checking update version..." -Percent 5 -Detail $Url
    try {
        return Invoke-RestMethod -Uri $Url -UseBasicParsing -TimeoutSec 30
    }
    catch {
        throw "Could not read online version info: $($_.Exception.Message)"
    }
}

function Get-PackageUrl {
    param($VersionInfo, [string]$ExplicitPackageUrl)

    if ($ExplicitPackageUrl) {
        return $ExplicitPackageUrl
    }

    $localPackagePath = Join-Path $PSScriptRoot "SeesumAI.bundle.zip"
    if (Test-Path -LiteralPath $localPackagePath) {
        return $localPackagePath
    }

    if ($VersionInfo.PSObject.Properties.Name -contains "installerPackageUrl") {
        return [string]$VersionInfo.installerPackageUrl
    }

    if ($VersionInfo.PSObject.Properties.Name -contains "packageUrl") {
        return [string]$VersionInfo.packageUrl
    }

    if ($VersionInfo.PSObject.Properties.Name -contains "downloadUrl") {
        return [string]$VersionInfo.downloadUrl
    }

    throw "Package URL was not found in version info."
}

function Request-AutoCADExit {
    param([int]$ProcessId)

    $targets = @()
    if ($ProcessId -gt 0) {
        $target = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($target) {
            $targets += $target
        }
    }

    if ($targets.Count -eq 0) {
        $targets = @(Get-Process -Name acad -ErrorAction SilentlyContinue)
    }

    foreach ($target in $targets) {
        try {
            $target.CloseMainWindow() | Out-Null
        }
        catch {
        }
    }
}

function Wait-AutoCADExit {
    $detail = if ($StartedFromAutoCAD) {
        "AutoCAD is closing automatically. Respond to any AutoCAD save prompt to continue."
    }
    else {
        "Close AutoCAD or respond to any AutoCAD save prompt to continue installing the update."
    }

    Set-InstallerProgress -Status "Waiting for AutoCAD to close..." -Percent 20 -Detail $detail
    Request-AutoCADExit -ProcessId $AutoCADPid
    $deadline = (Get-Date).AddMinutes(5)
    while ((Get-Process -Name acad -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Seconds 2
    }

    if (Get-Process -Name acad -ErrorAction SilentlyContinue) {
        throw "AutoCAD is still running. Respond to any AutoCAD save prompt, close AutoCAD, and run the installer again."
    }
}

function Resolve-PackagePath {
    param([string]$Source)

    if ($Source -match "^https?://") {
        $target = Join-Path $env:TEMP ("SeesumAI.bundle-" + [Guid]::NewGuid().ToString("N") + ".zip")
        Set-InstallerProgress -Status "Downloading update package..." -Percent 35 -Detail $Source
        Invoke-WebRequest -Uri $Source -OutFile $target -UseBasicParsing -TimeoutSec 120
        return $target
    }

    if ($Source -match "^file://") {
        return ([Uri]$Source).LocalPath
    }

    return $Source
}

function Find-BundleRoot {
    param([string]$ExtractRoot)

    $direct = Join-Path $ExtractRoot "SeesumAI.bundle"
    if ((Test-Path -LiteralPath (Join-Path $direct "PackageContents.xml")) -and
        (Test-Path -LiteralPath (Join-Path $direct "Contents"))) {
        return $direct
    }

    if ((Test-Path -LiteralPath (Join-Path $ExtractRoot "PackageContents.xml")) -and
        (Test-Path -LiteralPath (Join-Path $ExtractRoot "Contents"))) {
        return $ExtractRoot
    }

    $candidate = Get-ChildItem -LiteralPath $ExtractRoot -Directory -Recurse |
        Where-Object {
            (Test-Path -LiteralPath (Join-Path $_.FullName "PackageContents.xml")) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "Contents"))
        } |
        Select-Object -First 1

    if ($candidate) {
        return $candidate.FullName
    }

    throw "Could not find SeesumAI.bundle in extracted package."
}

function Get-BackupRoot {
    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        $localAppData = $env:LOCALAPPDATA
    }

    return Join-Path $localAppData "SeesumAI\AutoCAD\Backups"
}

function Test-CanWriteDirectory {
    param([string]$Path)

    try {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        $probe = Join-Path $Path (".seesumai-write-test-" + [Guid]::NewGuid().ToString("N"))
        Set-Content -LiteralPath $probe -Value "" -Encoding ASCII
        Remove-Item -LiteralPath $probe -Force
        return $true
    }
    catch {
        return $false
    }
}

function Get-TargetPluginsRoot {
    param([string]$ExplicitRoot)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitRoot)) {
        return $ExplicitRoot
    }

    $programDataPlugins = Join-Path $env:ProgramData "Autodesk\ApplicationPlugins"
    if (Test-CanWriteDirectory -Path $programDataPlugins) {
        return $programDataPlugins
    }

    return Join-Path $env:APPDATA "Autodesk\ApplicationPlugins"
}

function Get-UniqueBackupPath {
    param(
        [string]$BackupRoot,
        [string]$Name
    )

    $destination = Join-Path $BackupRoot $Name
    if (-not (Test-Path -LiteralPath $destination)) {
        return $destination
    }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    return Join-Path $BackupRoot "$Name.moved_$stamp"
}

function Move-PluginBackupsOut {
    param(
        [string]$TargetPlugins,
        [string]$TargetBundleName
    )

    if (-not (Test-Path -LiteralPath $TargetPlugins)) {
        return
    }

    $backupRoot = Get-BackupRoot
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

    $backupFilters = @("$TargetBundleName.backup_*", "$TargetBundleName.backup-*", "SeesumAI.bundle.backup_*", "SeesumAI.bundle.backup-*") | Select-Object -Unique
    foreach ($filter in $backupFilters) {
        Get-ChildItem -LiteralPath $TargetPlugins -Directory -Filter $filter -ErrorAction SilentlyContinue |
            ForEach-Object {
                $destination = Get-UniqueBackupPath -BackupRoot $backupRoot -Name $_.Name
                Move-Item -LiteralPath $_.FullName -Destination $destination
            }
    }
}

function Copy-BundleContents {
    param(
        [string]$SourceBundle,
        [string]$TargetBundle
    )

    New-Item -ItemType Directory -Force -Path $TargetBundle | Out-Null

    Get-ChildItem -LiteralPath $SourceBundle -Force -Recurse |
        ForEach-Object {
            $relative = $_.FullName.Substring($SourceBundle.Length)
            $relative = $relative.TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            $destination = Join-Path $TargetBundle $relative

            if ($_.PSIsContainer) {
                New-Item -ItemType Directory -Force -Path $destination | Out-Null
            }
            else {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
                Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
            }
        }
}

function Copy-BundleBackupBestEffort {
    param(
        [string]$SourceBundle,
        [string]$Backup
    )

    try {
        Copy-BundleContents -SourceBundle $SourceBundle -TargetBundle $Backup
    }
    catch {
        Set-InstallerProgress `
            -Status "Installing add-in files..." `
            -Percent 82 `
            -Detail "Backup copy skipped. Existing files will be updated in place.`r`n$($_.Exception.Message)"
    }
}

function Move-ExistingBundleToBackupOrOverlay {
    param(
        [string]$TargetBundle,
        [string]$Backup
    )

    if (-not (Test-Path -LiteralPath $TargetBundle)) {
        return $true
    }

    try {
        Move-Item -LiteralPath $TargetBundle -Destination $Backup
        return $true
    }
    catch {
        Set-InstallerProgress `
            -Status "Installing add-in files..." `
            -Percent 82 `
            -Detail "Existing bundle could not be moved. Installing over the current bundle.`r`n$($_.Exception.Message)"
        Copy-BundleBackupBestEffort -SourceBundle $TargetBundle -Backup $Backup
        return $false
    }
}

function TryDeleteOrRenameStaleFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    try {
        Remove-Item -LiteralPath $Path -Force
        return
    }
    catch {
    }

    $pendingName = (Split-Path -Leaf $Path) + ".delete_pending_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    try {
        Rename-Item -LiteralPath $Path -NewName $pendingName -Force
    }
    catch {
        Set-InstallerProgress `
            -Status "Installing add-in files..." `
            -Percent 90 `
            -Detail "Stale locked file will be ignored until AutoCAD restarts.`r`n$Path"
    }
}

function Remove-StalePayloadFiles {
    param([string]$TargetBundle)

    $windowsDir = Join-Path $TargetBundle "Contents\Windows"
    if (-not (Test-Path -LiteralPath $windowsDir)) {
        return
    }

    $allowedDlls = @(
        "SeesumAiRibbon_v53.dll",
        "SeesumAiUpdateChecker_v17.dll",
        "SeesumAiRibbonInfo_v14.dll",
        "SeesumAiDrawingNumber_v9.dll",
        "SeesumAiDrawingSplit_v7.dll",
        "SeesumAiBlockSync_v14.dll",
        "SeesumAiRe2Plus_v19.dll"
    )

    Get-ChildItem -LiteralPath $windowsDir -File -Filter "SeesumAi*.dll" -ErrorAction SilentlyContinue |
        Where-Object { $allowedDlls -notcontains $_.Name } |
        ForEach-Object { TryDeleteOrRenameStaleFile -Path $_.FullName }

    foreach ($staleIcon in @("manual.png", "manual_v2.png", "version.png")) {
        $path = Join-Path $windowsDir "Resources\$staleIcon"
        if (Test-Path -LiteralPath $path) {
            TryDeleteOrRenameStaleFile -Path $path
        }
    }
}

function Repair-Re2PlusDemandLoadCache {
    param([string]$TargetBundle)

    $loader = Join-Path $TargetBundle "Contents\Windows\SeesumAiRe2Plus_v19.dll"
    if (-not (Test-Path -LiteralPath $loader)) {
        return
    }
    $assemblyName = [IO.Path]::GetFileNameWithoutExtension($loader)

    $roots = @(
        "HKCU:\Software\Autodesk\AutoCAD",
        "HKCU:\Software\appdatalow\software\Autodesk\AutoCAD"
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -eq "Seesum AI RE2 Plus" -and $_.Name -like "*\Applications\Seesum AI RE2 Plus" } |
            ForEach-Object {
                Set-ItemProperty -LiteralPath $_.PSPath -Name "LOADER" -Value $loader -ErrorAction SilentlyContinue
                $profileKey = Split-Path -Parent (Split-Path -Parent $_.PSPath)
                $assemblyMap = Join-Path $profileKey "AssemblyMap"
                if (Test-Path -LiteralPath $assemblyMap) {
                    (Get-Item -LiteralPath $assemblyMap).Property |
                        Where-Object { $_ -like "SeesumAiRe2Plus_v*" } |
                        ForEach-Object { Remove-ItemProperty -LiteralPath $assemblyMap -Name $_ -ErrorAction SilentlyContinue }
                    Set-ItemProperty -LiteralPath $assemblyMap -Name $assemblyName -Value $loader -ErrorAction SilentlyContinue
                }

                $loadedRoot = Join-Path $profileKey "Loaded"
                if (Test-Path -LiteralPath $loadedRoot) {
                    Get-ChildItem -LiteralPath $loadedRoot -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -like "*SeesumAI.bundle*" -and $_.Name -like "*SeesumAiRe2Plus_v*.dll" -and $_.Name -notlike "*$assemblyName.dll" } |
                        Sort-Object PSPath -Descending |
                        ForEach-Object { Remove-Item -LiteralPath $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue }

                    Get-ChildItem -LiteralPath $loadedRoot -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.PSChildName -eq "#AssemblyMappings" -and $_.Name -like "*SeesumAI.bundle*" } |
                        ForEach-Object {
                            $mappingPath = $_.PSPath
                            $_.Property |
                                Where-Object { $_ -like "SeesumAiRe2Plus_v*" } |
                                ForEach-Object { Remove-ItemProperty -LiteralPath $mappingPath -Name $_ -ErrorAction SilentlyContinue }
                            Set-ItemProperty -LiteralPath $mappingPath -Name $assemblyName -Value "" -ErrorAction SilentlyContinue
                        }
                }
            }
    }
}

Initialize-InstallerWindow

try {
    if ($LocalPackagePath) {
        $packagePath = [IO.Path]::GetFullPath($LocalPackagePath)
    } else {
        $versionInfo = Read-VersionInfo -Url $VersionJsonUrl
        $resolvedPackageUrl = Get-PackageUrl -VersionInfo $versionInfo -ExplicitPackageUrl $PackageUrl
        $packagePath = Resolve-PackagePath -Source $resolvedPackageUrl
    }

    if (-not (Test-Path -LiteralPath $packagePath)) {
        throw "Package was not found: $packagePath"
    }

    Wait-AutoCADExit

    Set-InstallerProgress -Status "Extracting package..." -Percent 65 -Detail $packagePath
    $extractRoot = Join-Path $env:TEMP ("SeesumAI.bundle.extract-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
    Expand-Archive -LiteralPath $packagePath -DestinationPath $extractRoot -Force

    Set-InstallerProgress -Status "Installing add-in files..." -Percent 80 -Detail $TargetBundleName
    $bundleRoot = Find-BundleRoot -ExtractRoot $extractRoot
    $targetPlugins = Get-TargetPluginsRoot -ExplicitRoot $TargetPluginsRoot
    $targetBundle = Join-Path $targetPlugins $TargetBundleName
    New-Item -ItemType Directory -Force -Path $targetPlugins | Out-Null
    Move-PluginBackupsOut -TargetPlugins $targetPlugins -TargetBundleName $TargetBundleName

    if (Test-Path -LiteralPath $targetBundle) {
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupRoot = Get-BackupRoot
        New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
        $backup = Join-Path $backupRoot "$TargetBundleName.backup_$stamp"
        Move-ExistingBundleToBackupOrOverlay -TargetBundle $targetBundle -Backup $backup | Out-Null
    }

    Copy-BundleContents -SourceBundle $bundleRoot -TargetBundle $targetBundle
    $nestedBundle = Join-Path $targetBundle "SeesumAI.bundle"
    if (Test-Path -LiteralPath $nestedBundle) {
        Remove-Item -LiteralPath $nestedBundle -Recurse -Force
    }
    Remove-StalePayloadFiles -TargetBundle $targetBundle
    Repair-Re2PlusDemandLoadCache -TargetBundle $targetBundle

    Complete-InstallerWindow `
        -Status "Update installed." `
        -Detail "Open AutoCAD again to use the installed version.`r`n$targetBundle"
}
catch {
    Complete-InstallerWindow `
        -Status "Update failed." `
        -Detail $_.Exception.Message `
        -Failed $true
    exit 1
}
