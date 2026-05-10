$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
Set-Location $Root

function Have($Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

$bad = $false

function Check($Name) {
    if (Have $Name) {
        Write-Host "OK: $Name -> $((Get-Command $Name).Source)"
    } else {
        Write-Host "MISSING: $Name"
        $script:bad = $true
    }
}

Write-Host "== Repo =="
Write-Host $Root
git status --short

Write-Host ""
Write-Host "== Tools =="
Check git
Check rokit
Check rojo
Check selene
Check stylua
Check wally
Check lune

Write-Host ""
Write-Host "== Rojo project =="
$project = Get-ChildItem -Path . -Filter "*.project.json" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($project) {
    Write-Host "OK: Rojo project file -> $($project.Name)"
} else {
    Write-Host "MISSING: default.project.json or another *.project.json file"
    $bad = $true
}

if (Test-Path "src") {
    Write-Host "OK: src folder exists"
} else {
    Write-Host "WARNING: src folder not found"
}

Write-Host ""
Write-Host "== Config files =="
foreach ($file in @("rokit.toml", "selene.toml", ".stylua.toml", "wally.toml")) {
    if (Test-Path $file) {
        Write-Host "OK: $file"
    } else {
        Write-Host "MISSING/optional: $file"
    }
}
Write-Host ""
if ($bad) {
    Write-Host "Doctor found problems."
    exit 1
}

Write-Host "Doctor passed."
