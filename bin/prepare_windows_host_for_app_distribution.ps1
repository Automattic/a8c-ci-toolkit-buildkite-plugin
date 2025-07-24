# Prepares a `windows` CI agent with all the necessary setup so it can build and distribute a windows app
#
#  - Enables long path behavior
#  - Disable Windows Defender on the CI agent
#  - Install the "Chocolatey" package manager
#  - Install Python (required for Node.js native module compilation)(1)
#  - Enable dev mode so the agent can support Linux-style symlinks
#  - Download Code Signing Certificates(2)
#  - Install the Windows 10 SDK if it detected a `.windows-10-sdk-version` file(3)
#  - Optionally install native compilation tools (MSVC compiler and CMake)(4)
#
# (1) Python is NOT installed by default. You can install Python by calling the script with `-InstallPython`.
# (2) The certificate it installs is stored in our AWS SecretsManager storage (`windows-code-signing-certificate` secret ID)
# (3) You can skip the Windows 10 SDK installation regardless of whether `.windows-10-sdk-version` is present by calling the script with `-SkipWindows10SDKInstallation`.
# (4) Native compilation tools are NOT installed by default. You can install them by calling the script with `-InstallNativeCompilationTools`. This requires the Windows 10 SDK installation to NOT be skipped, as those are installed in tandem.
#
# Note: In addition to calling this script, and depending on your client app, you might want to also install `npm` and the `Node.js` packages used by your client app on the agent too. For that part, you should use the `automattic/nvm` Buildkite plugin on the pipeline step's `plugins:` attribute.
#

param (
  [switch]$SkipWindows10SDKInstallation = $false,
  [switch]$InstallPython = $false,
  [switch]$InstallNativeCompilationTools = $false
)

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

# Validate parameter combinations
if ($InstallNativeCompilationTools -and $SkipWindows10SDKInstallation) {
    throw "Invalid parameter combination: -InstallNativeCompilationTools cannot be used with -SkipWindows10SDKInstallation. Native compilation tools require Windows 10 SDK to be installed."
}

Write-Output "--- :windows: Setting up Windows for app distribution"

Write-Output "Current working directory: $PWD"

Write-Output "Enable long path behavior"
# See https://docs.microsoft.com/en-us/windows/desktop/fileio/naming-a-file#maximum-path-length-limitation
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1

# Disable Windows Defender before starting – otherwise our performance is terrible
Write-Output "Disable Windows Defender..."
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
  Write-Output "Set Microsoft Defender Antivirus to passive mode"
  Set-ItemProperty -Path $atpRegPath -Name 'ForceDefenderPassiveMode' -Value '1' -Type 'DWORD'
}

# From https://stackoverflow.com/a/46760714
Write-Output "--- :windows: Setting up Package Manager"
$env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

if ($InstallPython) {
  Write-Output "Run with InstallPython = true. Installing Python for Node.js native module compilation..."
  & "$PSScriptRoot\install_python.ps1"
  If ($LastExitCode -ne 0) { Exit $LastExitCode }
} else {
  Write-Output "Python installation not requested. Skipping Python installation."
}

# This should avoid issues with symlinks not being supported in Windows.
#
# See how this build failed
# https://buildkite.com/automattic/beeper-desktop/builds/2895#01919738-7c6e-4b82-8d1d-1c1800481740
Write-Output "--- :windows: :linux: Enable developer mode to use symlinks"

$developerMode = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

if ($developerMode.State -eq 'Enabled') {
  Write-Output "Developer Mode is already enabled."
} else {
  Write-Output "Enabling Developer Mode..."
  try {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
  } catch {
    Write-Output "Failed to enable Developer Mode. Continuing without it..."
  }
}

Write-Output "--- :lock_with_ink_pen: Download Code Signing Certificate"
$certificateBinPath = "certificate.bin"
$EncodedText = aws secretsmanager get-secret-value --secret-id windows-code-signing-certificate `
  | jq -r '.SecretString' `
  | Out-File $certificateBinPath
$certificatePfxPath = "certificate.pfx"
certutil -decode $certificateBinPath $certificatePfxPath
Write-Output "Code signing certificate downloaded at: $((Get-Item $certificatePfxPath).FullName)"

Write-Output "--- :windows: Checking whether to install Windows 10 SDK..."

# When using Electron Forge and electron2appx, building Appx requires the Windows 10 SDK
#
# See https://github.com/hermit99/electron-windows-store/tree/v2.1.2?tab=readme-ov-file#usage

if ($SkipWindows10SDKInstallation) {
  Write-Output "Run with SkipWindows10SDKInstallation = true. Skipping Windows 10 SDK installation check."
  Exit 0
}

$windowsSDKVersionFile = ".windows-10-sdk-version"
if (Test-Path $windowsSDKVersionFile) {
  Write-Output "Found $windowsSDKVersionFile file, installing Windows 10 SDK..."
  
  if ($InstallNativeCompilationTools) {
    & "$PSScriptRoot\install_windows_10_sdk.ps1" -InstallNativeCompilationTools
  } else {
    & "$PSScriptRoot\install_windows_10_sdk.ps1"
  }
  If ($LastExitCode -ne 0) { Exit $LastExitCode }
} else {
  Write-Output "No $windowsSDKVersionFile file found, skipping Windows 10 SDK installation."
}
