# Tests the prepare_windows_host_for_app_distribution.ps1 script with installation parameters.
#
# We only test the skip behavior and explicit installation requests because the installations take a "long" time to run.
# Tests both -InstallPython and -SkipWindows10SDKInstallation parameters.

param (
  [int]$ExpectedExitCode = 0
)

# Ensure the output is UTF-8 encoded so we can use emojis...
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$emojiGreenCheck = "$([char]0x2705)"
$emojiRedCross = "$([char]0x274C)"

function Test-ScriptWithParameters {
  param(
    [string]$TestName,
    [string[]]$Parameters,
    [string[]]$ExpectedMessages
  )
  
  Write-Output ""
  Write-Output "=== Testing $TestName ==="
  
  # Create a valid SDK version file to ensure it's not being used when skipped
  $sdkVersion = "20348"
  "$sdkVersion" | Out-File .windows-10-sdk-version
  
  # Run the script with specified parameters
  $paramString = $Parameters -join " "
  Write-Output "Running: prepare_windows_host_for_app_distribution.ps1 $paramString"
  
  $output = & "$PSScriptRoot\..\bin\prepare_windows_host_for_app_distribution.ps1" @Parameters
  $exitCode = $LASTEXITCODE
  
  # Check exit code
  if ($exitCode -ne $ExpectedExitCode) {
    Write-Output "$emojiRedCross Expected exit code $ExpectedExitCode, got $exitCode"
    Write-Output "Output was:"
    Write-Output "$output"
    exit 1
  } else {
    Write-Output "$emojiGreenCheck Exit code matches expected value ($ExpectedExitCode)"
  }
  
  # Check for expected messages
  foreach ($expectedMessage in $ExpectedMessages) {
    if ($output -match [regex]::Escape($expectedMessage)) {
      Write-Output "$emojiGreenCheck Found expected message: '$expectedMessage'"
    } else {
      Write-Output "$emojiRedCross Expected to find message: '$expectedMessage'"
      Write-Output "Full output was:"
      Write-Output "$output"
      exit 1
    }
  }
  
  Write-Output "$emojiGreenCheck $TestName completed successfully"
}

# Test 1: Default behavior - no Python installation, skip Windows 10 SDK for testing
Test-ScriptWithParameters -TestName "Default Behavior (No Python, Skip SDK)" `
  -Parameters @("-SkipWindows10SDKInstallation") `
  -ExpectedMessages @(
    "Python installation not requested. Skipping Python installation.",
    "Run with SkipWindows10SDKInstallation = true. Skipping Windows 10 SDK installation check."
  )

# Test 2: Explicitly install Python, skip Windows 10 SDK for testing
Test-ScriptWithParameters -TestName "Install Python (Skip SDK)" `
  -Parameters @("-SkipWindows10SDKInstallation", "-InstallPython") `
  -ExpectedMessages @(
    "Run with InstallPython = true. Installing Python for Node.js native module compilation...",
    "Run with SkipWindows10SDKInstallation = true. Skipping Windows 10 SDK installation check."
  )

# Additional verification: Ensure SDK was not installed when skipped
$windowsSDKsRoot = "C:\Program Files (x86)\Windows Kits\10\bin"
$sdkVersion = "20348"
$sdkPath = "$windowsSDKsRoot\10.0.$sdkVersion.0\x64"
If (Test-Path $sdkPath) {
  Write-Output "$emojiRedCross Found SDK installation at $sdkPath when it should have been skipped"
  exit 1
} else {
  Write-Output "$emojiGreenCheck Confirmed SDK was not installed at $sdkPath"
}

Write-Output ""
Write-Output "$emojiGreenCheck All tests completed successfully."
