# Alone, this does not fail
# & "$PSScriptRoot\command-that-fails-internally.ps1"

# To make the script fail, we need to check the error
& "$PSScriptRoot\command-that-fails-internally.ps1"

if ($LASTEXITCODE -ne 0) {
    # Using Write-Error doesn't print the exit code...
    # Write-Error "Script failed with exit code $LASTEXITCODE"
    #
    # ...will using Write-Host be better?
    Write-Host "Script failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
