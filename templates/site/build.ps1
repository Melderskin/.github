# Builds the site from src/ into dist/. Replace this with the site's own build when it needs one.
#   pwsh ./build.ps1    or    bash build.sh
Set-Location $PSScriptRoot
if (Test-Path dist) { Remove-Item -Recurse -Force dist }
Copy-Item -Recurse src dist
Write-Host 'Built dist/.'
