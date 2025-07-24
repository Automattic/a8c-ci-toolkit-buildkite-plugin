<#
.SYNOPSIS
    Installs Python 3 via Chocolatey.

.DESCRIPTION
    This script installs Python 3 using the Chocolatey package manager. Python is required
    for Node.js native module compilation as some Node.js packages require Python during
    npm install for building native extensions.

.PARAMETER DryRun
    When specified, the script will validate dependencies and show what would be installed
    without actually performing the installation.

.EXAMPLE
    .\install_python.ps1
    Installs Python 3 via Chocolatey.

.EXAMPLE
    .\install_python.ps1 -DryRun
    Validates dependencies and shows what would be installed without performing installation.

.NOTES
    Author: Automattic
    Requirements: Windows PowerShell 5.1
    Windows Requirements:
        - Windows Server 2019 or later
        - Chocolatey package manager must be installed
        - Administrator privileges: Yes

.OUTPUTS
    Status messages indicating installation progress and results.

.RETURNVALUES
    0 - Success
    1 - Installation failed
    Non-zero - Chocolatey installation exit code
#>

param (
  [switch]$DryRun = $false
)

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "--- :snake: Installing Python"

# Check if Chocolatey is available
try {
    $chocoPath = Get-Command choco -ErrorAction Stop
    Write-Output "Found Chocolatey at: $($chocoPath.Source)"
} catch {
    Write-Output "[!] Chocolatey is not installed or not available in PATH"
    Write-Output "    Please ensure Chocolatey is installed before running this script"
    Exit 1
}

Write-Output "Will attempt to install Python 3 via Chocolatey..."

if ($DryRun) {
  Write-Output "Running in dry run mode, finishing here."
  exit 0
}

# Install Python 3 via Chocolatey for Node.js native module compilation
# Some Node.js packages require Python during npm install for building native extensions
Write-Output "Installing Python 3 via Chocolatey..."
choco install python3 --yes --no-progress
If ($LastExitCode -ne 0) { 
    Write-Output "[!] Failed to install Python via Chocolatey"
    Exit $LastExitCode 
}

# Refresh environment to make Python available in PATH
Write-Output "Refreshing environment variables..."
& "$PSScriptRoot\path_aware_refreshenv.ps1"
If ($LastExitCode -ne 0) { 
    Write-Output "[!] Failed to refresh environment after Python installation"
    Exit $LastExitCode 
}

# Verify Python installation
Write-Output "Verifying Python installation..."
$pythonVersion = python --version 2>&1
If ($LastExitCode -eq 0) {
    Write-Output "Python installed successfully: $pythonVersion :tada:"
} else {
    Write-Output "[!] Python installation verification failed"
    Write-Output "    Python command not found in PATH after installation"
    Exit 1
}
