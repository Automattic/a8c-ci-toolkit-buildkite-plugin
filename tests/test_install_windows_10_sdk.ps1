param (
  [int]$ExpectedExitCode = 0,
  [string]$ExpectedErrorKeyphrase = ""
)

# Ensure the output is UTF-8 encoded so we can use emojis...
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$emojiGreenCheck = "$([char]0x2705)"
$emojiRedCross = "$([char]0x274C)"

Write-Output "Running $($MyInvocation.MyCommand.Name) with ExpectedExitCode=$ExpectedExitCode and ExpectedErrorKeyphrase=$ExpectedErrorKeyphrase"

if (($ExpectedExitCode -eq 0) -and ($ExpectedErrorKeyphrase -ne "")) {
  Write-Output "$emojiRedCross Expected call to succeed (expected error code = 0), but given an error keyphrase to check."
  exit 1
}

$output = & "$PSScriptRoot\..\bin\install_windows_10_sdk.ps1" -DryRun
$exitCode = $LASTEXITCODE

if ($exitCode -ne $ExpectedExitCode) {
  Write-Output "$emojiRedCross Expected exit code $ExpectedExitCode, got $exitCode"
  Write-Output "Output was:"
  Write-Output "$output"
  exit 1
} else {
  Write-Output "$emojiGreenCheck Exit code matches expected value ($ExpectedExitCode)"
}

# Only check error keyphrase if exit code is not 0
if ($exitCode -eq 0) {
  exit 0
}

# If keyphrase is empty, assume the caller is satisfied with only testing the exit code
if ($ExpectedErrorKeyphrase -eq "") {
  Write-Output "Exit code match expectation and no error keyphrase was provided. Test completed."
  exit 0
}

if ($output -match [regex]::Escape($ExpectedErrorKeyphrase)) {
  Write-Output "$emojiGreenCheck Error keyphrase matches expected value ($ExpectedErrorKeyphrase)"
  Write-Output "Test completed."
} else {
  Write-Output "$emojiRedCross Expected error to contain '$ExpectedErrorKeyphrase', but got:"
  Write-Output "$output"
  exit 1
}
