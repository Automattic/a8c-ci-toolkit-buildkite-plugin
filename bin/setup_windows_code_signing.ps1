<#
  .SYNOPSIS
    Installs the code signing certificate for Windows app distribution.

    The certificate is stored in our AWS SecretsManager storage (`windows-code-signing-certificate` secret ID).
    It is decoded and stored in the `certificate.pfx` file.
#>

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "--- :lock_with_ink_pen: Download Code Signing Certificate"

$certificateBinPath = "certificate.bin"

$secretJson = aws secretsmanager get-secret-value --secret-id windows-code-signing-certificate 2>&1
If ($LastExitCode -ne 0) {
  Write-Output "[!] Failed to retrieve secret from AWS SecretsManager."
  Write-Output $secretJson
  Exit $LastExitCode
}

$secretJson | jq -r '.SecretString' | Out-File $certificateBinPath
If ($LastExitCode -ne 0) {
  Write-Output "[!] Failed to parse secret JSON with jq."
  Exit $LastExitCode
}

$certificatePfxPath = "certificate.pfx"

certutil -decode $certificateBinPath $certificatePfxPath
If ($LastExitCode -ne 0) {
  Write-Output "[!] Failed to decode certificate."
  Exit $LastExitCode
}

Write-Output "Code signing certificate downloaded at: $((Get-Item $certificatePfxPath).FullName)"
