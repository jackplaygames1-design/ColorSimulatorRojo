$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
Set-Location $Root

.\scripts\check.ps1
.\scripts\build.ps1

Write-Host "Test/validation complete."
