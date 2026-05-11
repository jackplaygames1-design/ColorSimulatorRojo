This is a Roblox/Rojo project on Windows PowerShell.



Add a clean game sound system.



Create:

src/shared/AudioIds.luau

src/client/SoundController.client.luau



Goals:

\- Create SoundGroups:

&#x20; Master

&#x20; UI

&#x20; SFX

&#x20; Currency

&#x20; Hatch

&#x20; Ambience

&#x20; Tools

\- Add placeholder sound IDs in AudioIds.luau.

\- Add functions:

&#x20; PlayUI(name)

&#x20; PlaySFX(name)

&#x20; PlayCurrency(name)

&#x20; PlayHatch(name)

&#x20; PlayTool(name)

&#x20; PlayAtPosition(name, position)

\- Add safe handling for missing/blank sound IDs.

\- Do not break existing UI.

\- Wire basic UI click/open/close sounds where safe.

\- Do not rewrite the UI system.

\- Ignore warnings.



After changes, run:

.\\scripts\\check.ps1

.\\scripts\\build.ps1



Report where I paste real Roblox sound IDs.

