<#
.SYNOPSIS
    Sets up Azure Trusted Signing for Windows code signing in CI.

.DESCRIPTION
    Downloads the Azure Trusted Signing DLib and a modern `signtool.exe`,
    generates the metadata file Azure requires, verifies the .NET runtime
    is present (installs .NET 8 if not), and runs a smoke test to confirm
    signing works before the real build starts.

    On success, the following environment variables are set for downstream
    tools to consume:

    - `AZURE_CODE_SIGNING_DLIB` — path to `Azure.CodeSigning.Dlib.dll`
    - `AZURE_METADATA_JSON`     — path to generated `metadata.json`
    - `SIGNTOOL_PATH`           — path to modern `signtool.exe`
    - `AZURE_FILE_DIGEST`       — `SHA256`
    - `AZURE_TIMESTAMP_DIGEST`  — `SHA256`
    - `AZURE_TIMESTAMP_SERVER`  — `https://timestamp.acs.microsoft.com`

.PARAMETER SkipSmokeTest
    Skip the signing smoke test. Useful when Azure credentials are not
    yet available (e.g. during a dry-run).

.EXAMPLE
    & setup_azure_trusted_signing.ps1
    Runs the full setup including smoke test.

.EXAMPLE
    & setup_azure_trusted_signing.ps1 -SkipSmokeTest
    Runs the setup without verifying signing works.

.NOTES
    Version 1.0 - Initial release
    Requirements: Windows PowerShell 5.1
    Administrator privileges: No

    The following environment variables must be set before calling this
    script:

    - `AZURE_TENANT_ID`
    - `AZURE_CLIENT_ID`
    - `AZURE_CLIENT_SECRET`
    - `AZURE_ENDPOINT`
    - `AZURE_CODE_SIGNING_ACCOUNT`
    - `AZURE_CERTIFICATE_PROFILE`

.OUTPUTS
    Sets process-level environment variables (see DESCRIPTION).

.RETURNVALUES
    Exit code 0 on success, non-zero on failure.
#>

[CmdletBinding()]
param (
    [switch]$SkipSmokeTest
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ── Validate required environment variables ──────────────────────────

$REQUIRED_ENV_VARS = @(
    "AZURE_TENANT_ID",
    "AZURE_CLIENT_ID",
    "AZURE_CLIENT_SECRET",
    "AZURE_ENDPOINT",
    "AZURE_CODE_SIGNING_ACCOUNT",
    "AZURE_CERTIFICATE_PROFILE"
)

foreach ($var in $REQUIRED_ENV_VARS) {
    $value = [Environment]::GetEnvironmentVariable($var)
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Output "Error: Required environment variable $var is missing or empty"
        Exit 1
    }
}

$workingDir = Join-Path $env:TEMP ("AzureCodeSigning-" + [guid]::NewGuid().ToString())
$packageDir = Join-Path $workingDir "packages"
New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

# ── Download Azure Trusted Signing Client (DLib DLL) ─────────────────

Write-Output "~~~ Installing Microsoft.Trusted.Signing.Client NuGet package..."
$nupkgUrl = "https://www.nuget.org/api/v2/package/Microsoft.Trusted.Signing.Client/1.0.95"
$nupkgPath = Join-Path $packageDir "Microsoft.Trusted.Signing.Client.zip"
Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgPath
Expand-Archive -Path $nupkgPath -DestinationPath (Join-Path $packageDir "Microsoft.Trusted.Signing.Client") -Force

$dlibPath = (Get-ChildItem -Path $packageDir -Recurse -Filter "Azure.CodeSigning.Dlib.dll" |
    Where-Object { $_.FullName -like "*x64*" } |
    Select-Object -First 1).FullName

if (-not $dlibPath) {
    Write-Output "Error: Azure.CodeSigning.Dlib.dll not found"
    Exit 1
}
Write-Output "Found DLib at: $dlibPath"

# ── Download modern signtool (SDK 10.0.22621+) ──────────────────────
#
# Azure Trusted Signing requires the /dlib flag, which is only available
# in signtool from SDK 10.0.22621 or later.  CI agents typically ship
# with an older SDK, so we fetch a modern copy via the
# Microsoft.Windows.SDK.BuildTools NuGet package.

Write-Output "~~~ Installing modern signtool via Microsoft.Windows.SDK.BuildTools..."
$sdkToolsUrl = "https://www.nuget.org/api/v2/package/Microsoft.Windows.SDK.BuildTools/10.0.26100.7705"
$sdkToolsZip = Join-Path $packageDir "Microsoft.Windows.SDK.BuildTools.zip"
$sdkToolsDir = Join-Path $packageDir "Microsoft.Windows.SDK.BuildTools"
Invoke-WebRequest -Uri $sdkToolsUrl -OutFile $sdkToolsZip
Expand-Archive -Path $sdkToolsZip -DestinationPath $sdkToolsDir -Force

$signtoolPath = (Get-ChildItem -Path $sdkToolsDir -Recurse -Filter "signtool.exe" |
    Where-Object { $_.FullName -like "*x64*" } |
    Select-Object -First 1).FullName

if (-not $signtoolPath) {
    Write-Output "Error: signtool.exe not found in SDK BuildTools package"
    Exit 1
}
Write-Output "Found signtool at: $signtoolPath"

# ── Generate metadata.json ───────────────────────────────────────────
#
# Use the full resolved path to avoid 8.3 short names (e.g. BUILDK~1)
# which the Azure DLib may not handle.

$metadataPath = Join-Path $workingDir "metadata.json"

$metadata = @{
    Endpoint               = $env:AZURE_ENDPOINT
    CodeSigningAccountName = $env:AZURE_CODE_SIGNING_ACCOUNT
    CertificateProfileName = $env:AZURE_CERTIFICATE_PROFILE
    ExcludeCredentials     = @(
        "ManagedIdentityCredential"
        "WorkloadIdentityCredential"
        "SharedTokenCacheCredential"
        "VisualStudioCredential"
        "VisualStudioCodeCredential"
        "AzureCliCredential"
        "AzurePowerShellCredential"
        "AzureDeveloperCliCredential"
        "InteractiveBrowserCredential"
    )
} | ConvertTo-Json
Set-Content -Path $metadataPath -Value $metadata
Write-Output "Generated metadata.json at: $metadataPath"

# ── Ensure .NET 6+ runtime is available ──────────────────────────────
#
# The DLib is a C++/CLI assembly (via Ijwhost.dll) that requires the
# .NET runtime.

Write-Output "~~~ Checking .NET runtime..."
$dotnetRuntimes = $null
try { $dotnetRuntimes = & dotnet --list-runtimes 2>&1 } catch {}

$hasNet6Plus = $dotnetRuntimes |
    Where-Object { $_ -match "Microsoft\.NETCore\.App\s+([6-9]|[1-9]\d+)\." } |
    Select-Object -First 1

if (-not $hasNet6Plus) {
    Write-Output "Installing .NET 8 Runtime..."
    $dotnetInstallScript = "$env:TEMP\dotnet-install.ps1"
    Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstallScript
    & $dotnetInstallScript -Runtime dotnet -Channel 8.0 -InstallDir "$env:ProgramFiles\dotnet"
    If ($LastExitCode -ne 0) { Exit $LastExitCode }
    $env:PATH = "$env:ProgramFiles\dotnet;$env:PATH"
}

# ── Export environment variables ─────────────────────────────────────

$env:AZURE_CODE_SIGNING_DLIB = $dlibPath
$env:AZURE_METADATA_JSON = $metadataPath
$env:SIGNTOOL_PATH = $signtoolPath
$env:AZURE_FILE_DIGEST = "SHA256"
$env:AZURE_TIMESTAMP_DIGEST = "SHA256"
$env:AZURE_TIMESTAMP_SERVER = "https://timestamp.acs.microsoft.com"

# ── Smoke test ───────────────────────────────────────────────────────

if ($SkipSmokeTest) {
    Write-Output "Skipping signing smoke test."
} else {
    Write-Output "~~~ Smoke testing Azure Trusted Signing..."
    $dummyExe = Join-Path $workingDir "signing-test.exe"
    Copy-Item "C:\Windows\System32\cmd.exe" $dummyExe -Force

    $outFile = Join-Path $workingDir "signtool-out.txt"
    cmd /c "`"$signtoolPath`" sign /v /fd $env:AZURE_FILE_DIGEST /tr $env:AZURE_TIMESTAMP_SERVER /td $env:AZURE_TIMESTAMP_DIGEST /dlib `"$dlibPath`" /dmdf `"$metadataPath`" `"$dummyExe`" > `"$outFile`" 2>&1"
    $signtoolExitCode = $LastExitCode
    Get-Content $outFile
    Remove-Item $outFile -ErrorAction SilentlyContinue

    if ($signtoolExitCode -ne 0) {
        Write-Output "Error: Smoke test failed (exit code $signtoolExitCode)"
        Exit 1
    }
    Write-Output "Smoke test passed."
    Remove-Item $dummyExe -Force
}

Write-Output "Azure Trusted Signing is ready."

# Ensure $LastExitCode is 0 for callers that check it after & invocation.
cmd /c "exit 0"
