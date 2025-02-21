# Script: path_aware_refreshenv.ps1
#
# Description:
#   Wraps Chocolatey's `refreshenv` / `Update-SessionEnvironment` to avoid erasing PATH modifications.
#   Preserves PATH changes made during script execution while still refreshing other environment variables.
#
# Usage:
#   path_aware_refreshenv.ps1
#
# Options:
#   None
#
# Arguments:
#   None
#
# Examples:
#   # After installing a package that modifies PATH
#   choco install some-package
#   path_aware_refreshenv.ps1
#
# Notes:
#   - Saves PATH before refreshenv and restores unique entries after
#   - Use after installing packages that modify PATH at runtime
#   - See https://docs.chocolatey.org/en-us/create/cmdlets/update-sessionenvironment/
#
# Returns:
#   0 - Success
#   1 - Error in environment refresh
#
# Requirements:
#   - Windows PowerShell 5.1 or later
#   - Chocolatey package manager installed

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "PATH before refreshenv is $env:PATH"
$originalPath = "$env:PATH"
Write-Output "Calling refreshenv..."
refreshenv
$mergedPath = "$env:PATH;$originalPath" -split ";" | Select-Object -Unique -Skip 1
$env:PATH = ($mergedPath -join ";")
Write-Output "PATH after refreshenv is $env:PATH"
