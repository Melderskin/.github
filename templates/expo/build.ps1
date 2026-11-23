# Runs `npm run build` (package.json has the real command). PowerShell 7, every OS:  pwsh ./build.ps1  or  bash build.sh
Set-Location $PSScriptRoot
npm run build -- @args
exit $LASTEXITCODE
