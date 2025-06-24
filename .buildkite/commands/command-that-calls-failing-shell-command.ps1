npm # this should fail because npm is not setup in this repo

if ($LASTEXITCODE -ne 0) {
    Write-Error "Script failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
