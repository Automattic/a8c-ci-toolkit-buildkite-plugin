# Tests the prepare_windows_host_for_app_distribution.ps1 script with the -SkipWindows10SDKInstallation parameter.
#
# We only test the skip behavior because the installation takes a "long" time to run.

param (
  [int]$ExpectedExitCode = 0
)

# Ensure the output is UTF-8 encoded so we can use emojis...
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$emojiGreenCheck = "$([char]0x2705)"
$emojiRedCross = "$([char]0x274C)"

Write-Output "Testing prepare_windows_host_for_app_distribution.ps1 with -SkipWindows10SDKInstallation"

# Create a valid SDK version file to ensure it's not being used
$sdkVersion = "20348"
"$sdkVersion" | Out-File .windows-10-sdk-version

# Run the script with skip parameter
$output = & "$PSScriptRoot\..\bin\prepare_windows_host_for_app_distribution.ps1" -SkipWindows10SDKInstallation
$exitCode = $LASTEXITCODE

# Check exit code
if ($exitCode -ne $ExpectedExitCode) {
  Write-Output "$emojiRedCross Expected exit code $ExpectedExitCode, got $exitCode"
  Write-Output "Output was:"
  Write-Output "$output"
  Exit 1
} else {
  Write-Output "$emojiGreenCheck Exit code matches expected value ($ExpectedExitCode)"
}

$expectedSkipMessage = "Run with SkipWindows10SDKInstallation = true. Skipping Windows 10 SDK installation check."
if ($output -match [regex]::Escape($expectedSkipMessage)) {
  Write-Output "$emojiGreenCheck Found expected skip message in output"
} else {
  Write-Output "$emojiRedCross Expected to find message about skipping due to parameter, but got:"
  Write-Output "$output"
  Exit 1
}

# Verify SDK was not installed by checking the file system
$windowsSDKsRoot = "C:\Program Files (x86)\Windows Kits\10\bin"
$sdkPath = "$windowsSDKsRoot\10.0.$sdkVersion\x64"
If (Test-Path $sdkPath) {
  Write-Output "$emojiRedCross Found SDK installation at $sdkPath when it should have been skipped"
  Exit 1
} else {
  Write-Output "$emojiGreenCheck Confirmed SDK was not installed at $sdkPath"
}

# Test Python installation skip behavior (default case when -InstallPython is not used)
$expectedPythonSkipMessage = "Python installation not requested. Skipping Python installation."
if ($output -match [regex]::Escape($expectedPythonSkipMessage)) {
  Write-Output "$emojiGreenCheck Found expected Python skip message in output"
} else {
  Write-Output "$emojiRedCross Expected to find message about skipping Python installation, but got:"
  Write-Output "$output"
  Exit 1
}

Write-Output "Test completed successfully."
