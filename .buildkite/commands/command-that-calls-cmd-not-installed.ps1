$ErrorActionPreference = "Stop"

# This should fail because npm is not available out of the box on our Windows
# CI in 06/2025
npm

if ($LASTEXITCODE -ne 0) {
    Write-Host "Script failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
