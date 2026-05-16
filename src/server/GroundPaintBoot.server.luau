-- Explicit boot for the Ground Paint 2.0 core loop. Kept separate from the
-- legacy contamination script so Rojo/Studio startup is obvious.
local GroundPaintService = require(script.Parent:WaitForChild("GroundPaintService"))

GroundPaintService.Start()
