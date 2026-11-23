# Runs `npm run test` (package.json has the real command). PowerShell 7, every OS:  pwsh ./test.ps1  or  bash test.sh
Set-Location $PSScriptRoot
npm run test -- @args
exit $LASTEXITCODE
