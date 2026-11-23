# Runs the app locally. Fill in the project and the port for this repo.
#   pwsh ./serve.ps1    or    bash serve.sh
$Project = 'src/<Project>'
$Url = 'http://localhost:<port>'
Set-Location $PSScriptRoot
if ($Project -match '<|>') { Write-Host 'serve.ps1: fill in $Project and $Url at the top.' -ForegroundColor Yellow; exit 1 }
dotnet run --project $Project --urls $Url @args
exit $LASTEXITCODE
