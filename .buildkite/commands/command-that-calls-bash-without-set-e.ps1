$ErrorActionPreference = "Stop"

& "$PSScriptRoot\command-that-fails-without-set-e.sh"

if ($LastExitCode -ne 0) {
    Write-Host "Script failed with exit code $LastExitCode"
    exit $LastExitCode
}
