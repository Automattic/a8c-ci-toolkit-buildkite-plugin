# Alone, this does not fail
# & "$PSScriptRoot\command-that-fails-internally.ps1"

# To make the script fail, we need to check the error
& "$PSScriptRoot\command-that-fails-internally.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Script failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
