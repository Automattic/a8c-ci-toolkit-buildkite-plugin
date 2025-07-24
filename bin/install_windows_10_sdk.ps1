# Install the Windows 10 SDK and Visual Studio Build Tools using the value in .windows-10-sdk-version.
#
# The expected .windows-10-sdk-version format is an integer representing a valid SDK component id.
# The list of valid component ids can be found at
# https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022
#
# This script installs the Windows 10 SDK by default.
# Optionally, it can also install native compilation tools for building native modules:
# - MSVC v143 compiler toolset (x64/x86)
# - CMake tools for Visual Studio
#
# Example:
#
#   20348

param (
  [switch]$DryRun = $false,
  [switch]$InstallNativeCompilationTools = $false
)

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "--- :windows: Installing Windows 10 SDK and Visual Studio Build Tools"

# See list at https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022
$allowedVersions = @(
  "20348",
  "19041",
  "18362",
  "17763",
  "17134",
  "16299",
  "15063",
  "14393"
)

$windowsSDKVersionFile = ".windows-10-sdk-version"
if (-not (Test-Path $windowsSDKVersionFile)) {
  Write-Output "[!] No Windows 10 SDK version file found at $windowsSDKVersionFile."
  exit 1
}

$windows10SDKVersion = (Get-Content -TotalCount 1 $windowsSDKVersionFile).Trim()

if ($windows10SDKVersion -notmatch '^\d+$') {
  Write-Output "[!] Invalid version file format."
  Write-Output "Expected an integer, got: '$windows10SDKVersion'"
  exit 1
}

if ($allowedVersions -notcontains $windows10SDKVersion) {
  Write-Output "[!] Invalid Windows 10 SDK version: $windows10SDKVersion"
  Write-Output "Allowed versions are:"
  foreach ($version in $allowedVersions) {
    Write-Output "- $version"
  }
  Write-Output "More info at https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022"
  exit 1
}

Write-Output "Will attempt to set up Windows 10 ($windows10SDKVersion) SDK and Visual Studio Build Tools..."

if ($InstallNativeCompilationTools) {
  Write-Output "Native compilation tools requested. Will also install MSVC compiler toolset and CMake tools."
} else {
  Write-Output "Installing Windows 10 SDK only. Use -InstallNativeCompilationTools to include MSVC compiler and CMake tools."
}

if ($DryRun) {
  Write-Output "Running in dry run mode, finishing here."
  exit 0
}

# Download the Visual Studio Build Tools Bootstrapper
Write-Output "~~~ Downloading Visual Studio Build Tools..."

$buildToolsPath = ".\vs_buildtools.exe"

Invoke-WebRequest `
  -Uri https://aka.ms/vs/17/release/vs_buildtools.exe `
  -OutFile $buildToolsPath

If (-not (Test-Path $buildToolsPath)) {
  Write-Output "[!] Failed to download Visual Studio Build Tools"
  Exit 1
} else {
  Write-Output "Successfully downloaded Visual Studio Build Tools at $buildToolsPath."
}

# Install the Windows SDK and (optionally) native compilation tools
if ($InstallNativeCompilationTools) {
  Write-Output "~~~ Installing Visual Studio Build Tools with native compilation tools..."
} else {
  Write-Output "~~~ Installing Visual Studio Build Tools with Windows 10 SDK..."
}

# Define base components (always installed)
$components = @(
  "Microsoft.VisualStudio.Component.Windows10SDK.$windows10SDKVersion"
)

# Add native compilation tools if requested
if ($InstallNativeCompilationTools) {
  $components += @(
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",  # MSVC v143 compiler toolset
    "Microsoft.VisualStudio.Component.VC.CMake.Project"   # CMake tools for native modules
  )
}

$argumentList = "--quiet --wait"
foreach ($component in $components) {
  $argumentList += " --add $component"
}

Write-Output "Installing components: $($components -join ', ')"

Start-Process `
  -FilePath $buildToolsPath `
  -ArgumentList $argumentList `
  -NoNewWindow `
  -Wait

# Check if the installation was successful in file system
$windowsSDKsRoot = "C:\Program Files (x86)\Windows Kits\10\bin"
$sdkPath = "$windowsSDKsRoot\10.0.$windows10SDKVersion.0\x64"
If (-not (Test-Path $sdkPath)) {
  Write-Output "[!] Failed to install Windows 10 SDK: Could not find SDK at $sdkPath."
  If (-not (Test-Path $windowsSDKsRoot)) {
    Write-Output "[!] Expected $windowsSDKsRoot to exist, but it does not."
  } else {
    Write-Output "    Found:"
    Get-ChildItem -Path $windowsSDKsRoot | ForEach-Object { Write-Output "    - $windowsSDKsRoot\$_" }
  }
  Exit 1
}

Write-Output "Visual Studio Build Tools + Windows 10 ($windows10SDKVersion) SDK installation completed. SDK path: $sdkPath."
Write-Output "Windows 10 SDK path: $sdkPath."

Write-Output "~~~ Cleaning up..."
Remove-Item -Path $buildToolsPath
Write-Output "All cleaned up."
