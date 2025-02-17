# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

# It seems like calling refreshenv can erase PATH modifications that previous
# steps in an automation script might have made.
#
# See for example the logs in
# https://buildkite.com/automattic/beeper-desktop/builds/2893#01919717-d0d0-441d-a85d-0fe3223467d2/195
#
# To avoid the issue, we save the PATH pre-refreshenv and then manually add all
# the components that were removed.

Write-Host "PATH before refreshenv is $env:PATH"
$originalPath = "$env:PATH"
Write-Host "Calling refreshenv..."
refreshenv
$mergedPath = "$env:PATH;$originalPath" -split ";" | Select-Object -Unique -Skip 1
$env:PATH = ($mergedPath -join ";")
Write-Host "PATH after refreshenv is $env:PATH"

