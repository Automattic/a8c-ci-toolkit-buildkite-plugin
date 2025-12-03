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

$EncodedText = aws secretsmanager get-secret-value --secret-id windows-code-signing-certificate `
  | jq -r '.SecretString' `
  | Out-File $certificateBinPath

$certificatePfxPath = "certificate.pfx"

certutil -decode $certificateBinPath $certificatePfxPath

If ($LastExitCode -ne 0) {
  Write-Output "[!] Failed to download code signing certificate."
  Exit $LastExitCode
} else {
  Write-Output "Code signing certificate downloaded at: $((Get-Item $certificatePfxPath).FullName)"
}
