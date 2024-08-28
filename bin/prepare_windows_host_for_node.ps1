# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "--- :bug: Running as Administrator"
} else {
    Write-Host "--- :bug: Running as not Administrator"
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $roles = $principal.Identity.Groups | ForEach-Object {
        $_.Translate([Security.Principal.NTAccount]).Value
    }
    Write-Host "+++ Your roles are:"
    $roles | ForEach-Object { Write-Host "  - $_" }
}

Write-Host "--- :windows: Setting up Windows for Node and Electorn builds"

Write-Host "Enable long path behavior"
# See https://docs.microsoft.com/en-us/windows/desktop/fileio/naming-a-file#maximum-path-length-limitation
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1

# Disable Windows Defender before starting – otherwise our performance is terrible
Write-Host "Disable Windows Defender..."
$avPreference = @(
    @{DisableArchiveScanning = $true}
    @{DisableAutoExclusions = $true}
    @{DisableBehaviorMonitoring = $true}
    @{DisableBlockAtFirstSeen = $true}
    @{DisableCatchupFullScan = $true}
    @{DisableCatchupQuickScan = $true}
    @{DisableIntrusionPreventionSystem = $true}
    @{DisableIOAVProtection = $true}
    @{DisablePrivacyMode = $true}
    @{DisableScanningNetworkFiles = $true}
    @{DisableScriptScanning = $true}
    @{MAPSReporting = 0}
    @{PUAProtection = 0}
    @{SignatureDisableUpdateOnStartupWithoutEngine = $true}
    @{SubmitSamplesConsent = 2}
    @{ScanAvgCPULoadFactor = 5; ExclusionPath = @("D:\", "C:\")}
    @{DisableRealtimeMonitoring = $true}
    @{ScanScheduleDay = 8}
)

$avPreference += @(
    @{EnableControlledFolderAccess = "Disable"}
    @{EnableNetworkProtection = "Disabled"}
)

$avPreference | Foreach-Object {
    $avParams = $_
    Set-MpPreference @avParams
}

# https://github.com/actions/runner-images/issues/4277
# https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/microsoft-defender-antivirus-compatibility?view=o365-worldwide
$atpRegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
if (Test-Path $atpRegPath) {
    Write-Host "Set Microsoft Defender Antivirus to passive mode"
    Set-ItemProperty -Path $atpRegPath -Name 'ForceDefenderPassiveMode' -Value '1' -Type 'DWORD'
}

Write-Host "--- :lock_with_ink_pen: Downloading Code Signing Certificate"
$EncodedText = aws secretsmanager get-secret-value --secret-id windows-code-signing-certificate | jq -r '.SecretString' | Out-File 'certificate.bin'
certutil -decode certificate.bin certificate.pfx
If ($LastExitCode -ne 0) { Exit $LastExitCode }

# From https://stackoverflow.com/a/46760714
Write-Host "--- :windows: Setting up Package Manager"
$env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

Write-Host "--- :node: Installing NVM"
choco install nvm.portable -y
If ($LastExitCode -ne 0) { Exit $LastExitCode }

Write-Host "--- :hammer: Custom PATH refresh post NVM installation to avoid losing previous PATH changes"
Write-Host "PATH before refreshenv is $env:PATH"
# It looks like out of the box, calling refreshenv at this point erases various PATH modifications made by the rest of our automation.
#
# See https://buildkite.com/automattic/beeper-desktop/builds/2893#01919717-d0d0-441d-a85d-0fe3223467d2/195
#
# To avoid the issue, we save the PATH pre-refreshenv and then manually add all the components that were removed.
$originalPath = "$env:PATH"
refreshenv
$mergedPath = "$env:PATH;$originalPath" -split ";" | Select-Object -Unique -Skip 1
$env:PATH = ($mergedPath -join ";")
Write-Host "PATH after refreshenv is $env:PATH"

Write-Host "--- :node: Installing Node"
$nvmVersion=(Get-Content -Path .nvmrc -Total 1)
Write-Host "Switching to nvm version defined in .nvmrc: $nvmVersion"

nvm install $nvmVersion
nvm use $nvmVersion
If ($LastExitCode -ne 0) { Exit $LastExitCode }

Write-Host "--- :hammer: Custom PATH refresh post NVM installation to avoid losing previous PATH changes"
Write-Host "PATH before refreshenv is $env:PATH"
# It looks like out of the box, calling refreshenv at this point erases various PATH modifications made by the rest of our automation.
#
# See https://buildkite.com/automattic/beeper-desktop/builds/2893#01919717-d0d0-441d-a85d-0fe3223467d2/195
#
# To avoid the issue, we save the PATH pre-refreshenv and then manually add all the components that were removed.
$originalPath = "$env:PATH"
refreshenv
$mergedPath = "$env:PATH;$originalPath" -split ";" | Select-Object -Unique -Skip 1
$env:PATH = ($mergedPath -join ";")
Write-Host "PATH after refreshenv is $env:PATH"

# This should avoid issues with symlinks not being supported in Windows.
#
# See how this build failed
# https://buildkite.com/automattic/beeper-desktop/builds/2895#01919738-7c6e-4b82-8d1d-1c1800481740
Write-Host "--- :windows: :linux: Enable developer mode to use symlinks"

$developerMode = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

if ($developerMode.State -eq 'Enabled') {
    Write-Host "Developer Mode is already enabled."
} else {
    Write-Host "Enabling Developer Mode..."
    try {
      Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
    } catch {
      Write-Host "Failed to enable Developer Mode. Continuing without it..."
    }
}
