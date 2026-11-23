# Runs `npm run serve` (package.json has the real command). PowerShell 7, every OS:  pwsh ./serve.ps1  or  bash serve.sh
Set-Location $PSScriptRoot
npm run serve -- @args
exit $LASTEXITCODE
