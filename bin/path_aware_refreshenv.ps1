<#
.SYNOPSIS
    Refreshes environment variables while preserving PATH modifications.

.DESCRIPTION
    This script wraps Chocolatey's `refreshenv` / `Update-SessionEnvironment` command to refresh
    environment variables while preventing the loss of PATH modifications made during the current
    session. It's particularly useful in CI/CD pipelines where PATH modifications are needed
    across multiple steps.

.NOTES
    Author: Automattic Inc.
    Requirements: 
        - Windows PowerShell 5.1
        - Chocolatey package manager installed
    Windows Requirements:
        - Administrator privileges: No

.EXAMPLE
    .\path_aware_refreshenv.ps1
    Refreshes environment variables while preserving any PATH modifications made in the current session.

.OUTPUTS
    - Original PATH value
    - Confirmation of refreshenv execution
    - Updated PATH value after merging with original modifications

.RETURNVALUES
    0: Success
    1: Failure (if refreshenv fails or PATH manipulation errors occur)
#>

# Wraps Chocolatey's `refreshenv` / `Update-SessionEnvironment` to avoid erasing PATH modifications.
#
# See https://docs.chocolatey.org/en-us/create/cmdlets/update-sessionenvironment/
#
# Use this after installing a package via Chocolatey in a pipeline that modified the PATH at runtime, e.g. after adding a new binary to the PATH.
#
# It seems like calling refreshenv can erase PATH modifications that previous
# steps in an automation script might have made.
#
# See for example the logs in
# https://buildkite.com/automattic/beeper-desktop/builds/2893#01919717-d0d0-441d-a85d-0fe3223467d2/195
#
# To avoid the issue, we save the PATH pre-refreshenv and then manually add all
# the components that were removed.

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "PATH before refreshenv is $env:PATH"
$originalPath = "$env:PATH"
Write-Output "Calling refreshenv..."
refreshenv
$mergedPath = "$env:PATH;$originalPath" -split ";" | Select-Object -Unique -Skip 1
$env:PATH = ($mergedPath -join ";")
Write-Output "PATH after refreshenv is $env:PATH"
