# Runs every test in the solution. Some repos' tests need a database: see README.md, "Tests".
#   pwsh ./test.ps1    or    bash test.sh    (more options go to dotnet test, for example --filter Name~Tenant)
Set-Location $PSScriptRoot
dotnet test --nologo @args
exit $LASTEXITCODE
