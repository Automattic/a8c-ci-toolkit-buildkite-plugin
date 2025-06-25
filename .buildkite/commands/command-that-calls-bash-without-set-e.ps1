$ErrorActionPreference = "Stop"

& "$PSScriptRoot\command-that-fails-without-set-e.sh" /c exit 1

if ($LastExitCode -ne 0) {
    Write-Host "Script failed with exit code $LastExitCode"
    exit $LastExitCode
}
