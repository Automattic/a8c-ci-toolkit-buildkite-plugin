$ErrorActionPreference = "Stop"

npm # this should fail because npm is not setup in this repo

if ($LASTEXITCODE -ne 0) {
    Write-Host "Script failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
