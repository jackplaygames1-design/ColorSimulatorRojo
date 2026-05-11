This is a Roblox/Rojo project on Windows PowerShell.



Add a simple VFX system.



Create:

src/shared/VFXConfig.luau

src/client/VFXController.client.luau



Goals:

\- Add helper functions:

&#x20; PlayPaintPop(position, color)

&#x20; PlayCoinPickup(position)

&#x20; PlayGemBreak(position)

&#x20; PlayHatchBurst(position, rarity)

&#x20; PlayMutationReveal(position, mutationName)

&#x20; PlayPortalPulse(position, color)

\- Use Roblox ParticleEmitter, Beam, Trail, TweenService, and simple parts where appropriate.

\- Keep effects lightweight.

\- No massive particle spam.

\- Do not rewrite gameplay systems.

\- Ignore warnings.



After changes, run:

.\\scripts\\check.ps1

.\\scripts\\build.ps1

