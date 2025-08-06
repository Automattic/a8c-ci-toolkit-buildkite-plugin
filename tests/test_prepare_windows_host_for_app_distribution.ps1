# Tests the prepare_windows_host_for_app_distribution.ps1 script with various parameter combinations.
#
# This test covers multiple scenarios:
# 1. -SkipWindows10SDKInstallation (should skip SDK installation check entirely)
# 2. -SkipWindows10SDKInstallation -InstallNativeCompilationTools (should fail with validation error)
# 3. No .windows-10-sdk-version file with -InstallNativeCompilationTools (should skip installation - no version file available)
# 4. No .windows-10-sdk-version file without -InstallNativeCompilationTools (should skip installation)
#
# Note: These tests focus on parameter validation and decision logic only, without performing
# expensive installations or downloads.

param (
  [int]$ExpectedExitCode = 0
)

# Ensure the output is UTF-8 encoded so we can use emojis...
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$emojiGreenCheck = "$([char]0x2705)"
$emojiRedCross = "$([char]0x274C)"

# Skip certificate download for all tests to avoid AWS credential issues
$env:SKIP_CERTIFICATE_DOWNLOAD = "true"

Write-Output "Testing prepare_windows_host_for_app_distribution.ps1 with various parameter combinations"

# Function to clean up test files
function Remove-TestFiles {
  if (Test-Path ".windows-10-sdk-version") {
    Remove-Item ".windows-10-sdk-version" -Force
  }
  if (Test-Path "vs_buildtools.exe") {
    Remove-Item "vs_buildtools.exe" -Force
  }
}

# Test 1: -SkipWindows10SDKInstallation (should skip both SDK and native tools)
Write-Output "`n--- Test 1: Skip SDK installation without native tools"
Remove-TestFiles

# Create a valid SDK version file to ensure it's not being used when skip is set
$sdkVersion = "19041"
"$sdkVersion" | Out-File .windows-10-sdk-version

$output = & "$PSScriptRoot\..\bin\prepare_windows_host_for_app_distribution.ps1" -SkipWindows10SDKInstallation
$exitCode = $LASTEXITCODE

if ($exitCode -ne $ExpectedExitCode) {
  Write-Output "$emojiRedCross Test 1: Expected exit code $ExpectedExitCode, got $exitCode"
  Write-Output "Output was:"
  Write-Output "$output"
  Exit 1
} else {
  Write-Output "$emojiGreenCheck Test 1: Exit code matches expected value ($ExpectedExitCode)"
}

$expectedSkipMessage = "Skipping Windows 10 SDK installation check"
if ($output -match [regex]::Escape($expectedSkipMessage)) {
  Write-Output "$emojiGreenCheck Test 1: Found expected skip message in output"
} else {
  Write-Output "$emojiRedCross Test 1: Expected to find skip message, but got:"
  Write-Output "$output"
  Exit 1
}

# Test 2: -SkipWindows10SDKInstallation -InstallNativeCompilationTools (should fail with validation error)
Write-Output "`n--- Test 2: Invalid parameter combination - skip SDK but attempt native compilation tools"
Remove-TestFiles

# Create a valid SDK version file (irrelevant since validation should fail before processing)
"$sdkVersion" | Out-File .windows-10-sdk-version

$output = & "$PSScriptRoot\..\bin\prepare_windows_host_for_app_distribution.ps1" -SkipWindows10SDKInstallation -InstallNativeCompilationTools 2>&1
$exitCode = $LASTEXITCODE

# Expect the script to fail with a validation error (non-zero exit code)
if ($exitCode -eq 0) {
  Write-Output "$emojiRedCross Test 2: Expected script to fail with validation error, but it succeeded with exit code $exitCode"
  Write-Output "Output was:"
  Write-Output "$output"
  Exit 1
} else {
  Write-Output "$emojiGreenCheck Test 2: Script correctly failed with validation error (exit code $exitCode)"
}

# Check for our validation error message
if ($output -match "Invalid parameter combination") {
  Write-Output "$emojiGreenCheck Test 2: Found expected validation error message"
} else {
  Write-Output "$emojiRedCross Test 2: Expected validation error not found. Output:"
  Write-Output "$output"
  Exit 1
}

# Test 3: No .windows-10-sdk-version file with -InstallNativeCompilationTools (should skip installation)
Write-Output "`n--- Test 3: No SDK version file with native compilation tools requested"
Remove-TestFiles

$output = & "$PSScriptRoot\..\bin\prepare_windows_host_for_app_distribution.ps1" -InstallNativeCompilationTools 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -ne $ExpectedExitCode) {
  Write-Output "$emojiRedCross Test 3: Expected exit code $ExpectedExitCode, got $exitCode"
  Write-Output "Output was:"
  Write-Output "$output"
  Exit 1
} else {
  Write-Output "$emojiGreenCheck Test 3: Exit code matches expected value ($ExpectedExitCode)"
}

$expectedNoFileSkipMessage = "No .windows-10-sdk-version file found"
if ($output -match [regex]::Escape($expectedNoFileSkipMessage)) {
  Write-Output "$emojiGreenCheck Test 3: Found expected skip message when no version file exists"
} else {
  Write-Output "$emojiRedCross Test 3: Expected to find skip message, but got:"
  Write-Output "$output"
  Exit 1
}

# Test 4: No .windows-10-sdk-version file without -InstallNativeCompilationTools (should skip everything)
Write-Output "`n--- Test 4: No SDK version file and no native tools requested"
Remove-TestFiles

$output = & "$PSScriptRoot\..\bin\prepare_windows_host_for_app_distribution.ps1"
$exitCode = $LASTEXITCODE

if ($exitCode -ne $ExpectedExitCode) {
  Write-Output "$emojiRedCross Test 4: Expected exit code $ExpectedExitCode, got $exitCode"
  Write-Output "Output was:"
  Write-Output "$output"
  Exit 1
} else {
  Write-Output "$emojiGreenCheck Test 4: Exit code matches expected value ($ExpectedExitCode)"
}

$expectedNoFileSkipMessage = "No .windows-10-sdk-version file found"
if ($output -match [regex]::Escape($expectedNoFileSkipMessage)) {
  Write-Output "$emojiGreenCheck Test 4: Found expected no-file skip message"
} else {
  Write-Output "$emojiRedCross Test 4: Expected to find no-file skip message, but got:"
  Write-Output "$output"
  Exit 1
}

# Clean up
Remove-TestFiles

Write-Output "`n$emojiGreenCheck All tests completed successfully."
