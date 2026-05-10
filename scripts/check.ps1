$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
Set-Location $Root

function Have($Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

$target = "."
if (Test-Path "src") {
    $target = "src"
}

if (Have "stylua") {
    Write-Host "== StyLua format check =="
    stylua --check --glob "**/*.luau" --glob "**/*.lua" -- $target
} else {
    Write-Host "Skipping StyLua: command not found"
}

if (Have "selene") {
    Write-Host "== Selene lint =="
    selene $target
} else {
    Write-Host "Skipping Selene: command not found"
}

Write-Host "Checks complete."
