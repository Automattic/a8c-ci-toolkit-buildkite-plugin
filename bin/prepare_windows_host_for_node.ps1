# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

$newScript = "prepare_windows_host_for_app_distribution.ps1"

Write-Host "+++ :warning: This command is deprecated"
Write-Host "Please use $newScript instead"
Write-Host "Now calling $newScript..."

& "$PSScriptRoot\$newScript"
