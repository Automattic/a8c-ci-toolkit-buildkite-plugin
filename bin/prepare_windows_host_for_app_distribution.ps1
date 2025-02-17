# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Host "Current working directory: $PWD"

Write-Host "--- :windows: Setting up Windows for Node and Electron builds"

Write-Host "Enable long path behavior"
# See https://docs.microsoft.com/en-us/windows/desktop/fileio/naming-a-file#maximum-path-length-limitation
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1

# Disable Windows Defender before starting – otherwise our performance is terrible
Write-Host "Disable Windows Defender..."
$avPreference = @(
    @{DisableArchiveScanning = $true}
    @{DisableAutoExclusions = $true}
    @{DisableBehaviorMonitoring = $true}
    @{DisableBlockAtFirstSeen = $true}
    @{DisableCatchupFullScan = $true}
    @{DisableCatchupQuickScan = $true}
    @{DisableIntrusionPreventionSystem = $true}
    @{DisableIOAVProtection = $true}
    @{DisablePrivacyMode = $true}
    @{DisableScanningNetworkFiles = $true}
    @{DisableScriptScanning = $true}
    @{MAPSReporting = 0}
    @{PUAProtection = 0}
    @{SignatureDisableUpdateOnStartupWithoutEngine = $true}
    @{SubmitSamplesConsent = 2}
    @{ScanAvgCPULoadFactor = 5; ExclusionPath = @("D:\", "C:\")}
    @{DisableRealtimeMonitoring = $true}
    @{ScanScheduleDay = 8}
)

$avPreference += @(
    @{EnableControlledFolderAccess = "Disable"}
    @{EnableNetworkProtection = "Disabled"}
)

$avPreference | Foreach-Object {
    $avParams = $_
    Set-MpPreference @avParams
}

# https://github.com/actions/runner-images/issues/4277
# https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/microsoft-defender-antivirus-compatibility?view=o365-worldwide
$atpRegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
if (Test-Path $atpRegPath) {
    Write-Host "Set Microsoft Defender Antivirus to passive mode"
    Set-ItemProperty -Path $atpRegPath -Name 'ForceDefenderPassiveMode' -Value '1' -Type 'DWORD'
}

Write-Host "--- :lock_with_ink_pen: Downloading Code Signing Certificate"
$EncodedText = aws secretsmanager get-secret-value --secret-id windows-code-signing-certificate | jq -r '.SecretString' | Out-File 'certificate.bin'
certutil -decode certificate.bin certificate.pfx
Write-Host "Code signing certificate downloaded at: $((Get-Item 'certificate.pfx').FullName)"
If ($LastExitCode -ne 0) { Exit $LastExitCode }

# From https://stackoverflow.com/a/46760714
Write-Host "--- :windows: Setting up Package Manager"
$env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

# This should avoid issues with symlinks not being supported in Windows.
#
# See how this build failed
# https://buildkite.com/automattic/beeper-desktop/builds/2895#01919738-7c6e-4b82-8d1d-1c1800481740
Write-Host "--- :windows: :linux: Enable developer mode to use symlinks"

$developerMode = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

if ($developerMode.State -eq 'Enabled') {
    Write-Host "Developer Mode is already enabled."
} else {
    Write-Host "Enabling Developer Mode..."
    try {
      Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
    } catch {
      Write-Host "Failed to enable Developer Mode. Continuing without it..."
    }
}
