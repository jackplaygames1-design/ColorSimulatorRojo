$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
Set-Location $Root

function Have($Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

Write-Host "== ColorSimulatorRojo Roblox/Rojo setup =="

if (-not (Have "git")) {
    Write-Host "MISSING: Git for Windows."
    Write-Host "Install Git, reopen PowerShell, then rerun this script."
    exit 1
}

if (-not (Have "rokit")) {
    Write-Host "Installing Rokit..."
    Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
    Refresh-Path
}

if (-not (Have "rokit")) {
    Write-Host ""
    Write-Host "Rokit was installed, but this terminal does not see it yet."
    Write-Host "Close this PowerShell window, open a new PowerShell in:"
    Write-Host "C:\Users\jackp\ColorSimulatorRojo"
    Write-Host "Then run:"
    Write-Host ".\scripts\setup.ps1"
    exit 1
}

Write-Host "== Rokit =="
rokit --version

if (-not (Test-Path "rokit.toml")) {
    Write-Host "Creating rokit.toml..."
    rokit init
}

$tools = @(
    "rojo-rbx/rojo",
    "Kampfkarren/selene",
    "JohnnyMorganz/StyLua",
    "UpliftGames/wally",
    "lune-org/lune"
)

foreach ($tool in $tools) {
    $text = ""
    if (Test-Path "rokit.toml") {
        $text = Get-Content "rokit.toml" -Raw
    }

    if ($text -notmatch [regex]::Escape($tool)) {
        Write-Host "Adding tool: $tool"
        rokit add $tool
    }
}

Write-Host "== Installing project tools =="
rokit install
Refresh-Path

Write-Host "== Tool versions =="
if (Have "rojo") { rojo --version } else { Write-Host "MISSING: rojo" }
if (Have "selene") { selene --version } else { Write-Host "MISSING: selene" }
if (Have "stylua") { stylua --version } else { Write-Host "MISSING: stylua" }
if (Have "wally") { wally --version } else { Write-Host "MISSING: wally" }
if (Have "lune") { lune --version } else { Write-Host "MISSING: lune" }

if ((Test-Path "wally.toml") -and (Have "wally")) {
    Write-Host "== Wally packages =="
    wally install
}

if (Have "rojo") {
    try {
        Write-Host "== Installing/updating Rojo Studio plugin =="
        rojo plugin install
    } catch {
        Write-Host "Rojo plugin install skipped/failed. You can run later:"
        Write-Host "rojo plugin install"
    }
}

Write-Host ""
Write-Host "Setup complete."
