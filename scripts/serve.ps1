$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
Set-Location $Root

$project = Get-ChildItem -Path . -Filter "*.project.json" -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $project) {
    Write-Host "No *.project.json file found. Expected default.project.json."
    exit 1
}

if (-not (Get-Command rojo -ErrorAction SilentlyContinue)) {
    Write-Host "MISSING: rojo. Run .\scripts\setup.ps1 first."
    exit 1
}

Write-Host "Starting Rojo live sync server with $($project.Name)"
rojo serve $project.FullName
