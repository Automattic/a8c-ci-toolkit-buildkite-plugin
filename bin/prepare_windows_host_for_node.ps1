# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Host "+++ :warning: This command is deprecated"
Write-Host "Please use prepare_windows_host_for_app_distribution.ps1 instead"
Write-Host "Now calling prepare_windows_host_for_app_distribution.ps1..."

& "$PSScriptRoot\prepare_windows_host_for_app_distribution.ps1"
