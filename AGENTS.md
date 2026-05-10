# AGENTS.md

## Project
ColorSimulatorRojo is a Roblox game project using Rojo.

## Important
This is a Windows PowerShell workflow. Do not give Bash-only commands such as chmod, cat <<EOF, if/then/fi, or cargo setup unless Rust is actually needed.

## Setup
Run:

.\scripts\setup.ps1

## Doctor
Run:

.\scripts\doctor.ps1

## Check code
Run:

.\scripts\check.ps1

## Format code
Run:

.\scripts\format.ps1

## Build Roblox place file
Run:

.\scripts\build.ps1

## Start Rojo live sync
Run:

.\scripts\serve.ps1

Then open Roblox Studio, open the Rojo plugin, and connect to the running server.

## Rules
- Use Rokit-managed tools.
- Use Rojo for Roblox Studio sync.
- Do not randomly install tools with cargo, pip, or npm unless the repo clearly needs them.
- Do not modify large Roblox assets unless asked.
- Keep changes inside src/client, src/server, src/shared, or src/modules unless there is a clear reason.
- After code changes, run .\scripts\check.ps1.
- After structural Rojo changes, run .\scripts\build.ps1.
