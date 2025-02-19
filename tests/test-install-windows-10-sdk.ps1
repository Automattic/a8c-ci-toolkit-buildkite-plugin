param (
  [int]$ExpectedExitCode = 0,
  [string]$ExpectedErrorKeyphrase = ""
)

$ErrorActionPreference = "Stop"

if (($ExpectedExitCode -eq 0) -and ($ExpectedErrorKeyphrase -ne "")) {
  Write-Error "Expected call to succeed, but given an error keyphrase to check."
  exit 1
}

$output = "$PSScriptRoot\..\bin\install_windows_10_sdk.ps1 -DryRun"
$exitCode = $LASTEXITCODE

if ($exitCode -ne $ExpectedExitCode) {
  Write-Error "Expected exit code $ExpectedExitCode, got $exitCode"
  exit 1
}

# Only check error keyphrase if exit code is not 0
if ($exitCode -eq 0) {
  exit 0
}

if ($output -notmatch $ExpectedErrorKeyphrase) {
  Write-Error "Expected error to contain '$ExpectedErrorKeyphrase', but got:"
  Write-Error "$output"
  exit 1
}
