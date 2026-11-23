# Builds the solution. Warnings are errors (Directory.Build.props). PowerShell 7, every OS:  pwsh ./build.ps1  or  bash build.sh
Set-Location $PSScriptRoot
dotnet build --nologo @args
exit $LASTEXITCODE
