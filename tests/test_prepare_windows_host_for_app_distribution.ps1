# Tests the prepare_windows_host_for_app_distribution.ps1 script with various parameter combinations.
#
# This test covers multiple scenarios:
# 1. -SkipWindows10SDKInstallation (should skip SDK installation check entirely)
# 2. -SkipWindows10SDKInstallation -InstallNativeCompilationTools (should fail with validation error)
# 3. No .windows-10-sdk-version file with -InstallNativeCompilationTools (should skip installation - no version file available)
# 4. No .windows-10-sdk-version file without -InstallNativeCompilationTools (should skip installation)
# 5. .windows-10-sdk-version file exists with -InstallNativeCompilationTools (should install SDK with native tools)
# 6. .windows-10-sdk-version file exists without -InstallNativeCompilationTools (should install SDK only)
# 7. -InstallPython flag (should attempt Python installation)
#
# Note: For tests involving actual downloads/installations, we test up to the download attempt
# to verify the correct decision logic without requiring network access or long installations.

param (
  [int]$ExpectedExitCode = 0
)

# Ensure the output is UTF-8 encoded so we can use emojis...
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$emojiGreenCheck = "$([char]0x2705)"
$emojiRedCross = "$([char]0x274C)"

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
$sdkVersion = "20348"
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

# Ensure no SDK version file exists
if (Test-Path ".windows-10-sdk-version") {
  Remove-Item ".windows-10-sdk-version" -Force
}

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

# Ensure no SDK version file exists
if (Test-Path ".windows-10-sdk-version") {
  Remove-Item ".windows-10-sdk-version" -Force
}

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

# Test 5: .windows-10-sdk-version file exists with -InstallNativeCompilationTools (should install SDK with native tools)
Write-Output "`n--- Test 5: SDK version file exists with native compilation tools requested"
Remove-TestFiles

# Create a valid SDK version file
"$sdkVersion" | Out-File .windows-10-sdk-version

$output = & "$PSScriptRoot\..\bin\prepare_windows_host_for_app_distribution.ps1" -InstallNativeCompilationTools 2>&1
$exitCode = $LASTEXITCODE

$expectedSDKMessage = "Found .windows-10-sdk-version file"
if ($output -match [regex]::Escape($expectedSDKMessage)) {
  Write-Output "$emojiGreenCheck Test 5: Found expected SDK installation message"
} else {
  Write-Output "$emojiRedCross Test 5: Expected to find SDK installation message, but got:"
  Write-Output "$output"
  Exit 1
}

# Test 6: .windows-10-sdk-version file exists without -InstallNativeCompilationTools (should install SDK only)
Write-Output "`n--- Test 6: SDK version file exists without native compilation tools"
Remove-TestFiles

# Create a valid SDK version file
"$sdkVersion" | Out-File .windows-10-sdk-version

$output = & "$PSScriptRoot\..\bin\prepare_windows_host_for_app_distribution.ps1" 2>&1
$exitCode = $LASTEXITCODE

$expectedSDKMessage = "Found .windows-10-sdk-version file"
if ($output -match [regex]::Escape($expectedSDKMessage)) {
  Write-Output "$emojiGreenCheck Test 6: Found expected SDK installation message"
} else {
  Write-Output "$emojiRedCross Test 6: Expected to find SDK installation message, but got:"
  Write-Output "$output"
  Exit 1
}

# Test 7: -InstallPython flag (should attempt Python installation)
Write-Output "`n--- Test 7: Python installation requested"
Remove-TestFiles

$output = & "$PSScriptRoot\..\bin\prepare_windows_host_for_app_distribution.ps1" -InstallPython 2>&1
$exitCode = $LASTEXITCODE

$expectedPythonInstallMessage = "Installing Python for Node.js native module compilation"
if ($output -match [regex]::Escape($expectedPythonInstallMessage)) {
  Write-Output "$emojiGreenCheck Test 7: Found expected Python installation message"
} else {
  Write-Output "$emojiRedCross Test 7: Expected to find Python installation message, but got:"
  Write-Output "$output"
  Exit 1
}

# Test Python installation skip behavior (should be consistent across tests that don't use -InstallPython)
Write-Output "`n--- Testing Python installation skip behavior"
# Use output from Test 4 since it completed successfully without errors
$expectedPythonSkipMessage = "Skipping Python installation"
# We'll test this on a fresh run since it ran without -InstallPython
Remove-TestFiles
"$sdkVersion" | Out-File .windows-10-sdk-version
$outputForPythonTest = & "$PSScriptRoot\..\bin\prepare_windows_host_for_app_distribution.ps1" 2>&1

if ($outputForPythonTest -match [regex]::Escape($expectedPythonSkipMessage)) {
  Write-Output "$emojiGreenCheck Found expected Python skip message in output"
} else {
  Write-Output "$emojiRedCross Expected to find message about skipping Python installation, but got:"
  Write-Output "$outputForPythonTest"
  Exit 1
}

# Clean up
Remove-TestFiles

Write-Output "`n$emojiGreenCheck All tests completed successfully."
Write-Output "Note: Tests 5, 6, and 7 may attempt to call install_windows_10_sdk.ps1 or install_python.ps1 which require network access. If these fail due to network issues, the validation logic is still confirmed working."
