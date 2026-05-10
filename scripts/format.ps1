$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
Set-Location $Root

$target = "."
if (Test-Path "src") {
    $target = "src"
}

if (-not (Get-Command stylua -ErrorAction SilentlyContinue)) {
    Write-Host "MISSING: stylua. Run .\scripts\setup.ps1 first."
    exit 1
}

stylua --glob "**/*.luau" --glob "**/*.lua" -- $target

Write-Host "Formatting complete."
