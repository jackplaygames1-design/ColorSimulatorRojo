local PetVisualService = require(script.Parent:WaitForChild("PetVisualService"))

local publishedCount = PetVisualService.PublishToReplicatedStorage()
if publishedCount > 0 then
	print(
		"PetAppearancePublisher: published "
			.. tostring(publishedCount)
			.. " editable Color templates from PetAppearanceStudio."
	)
else
	print("PetAppearancePublisher: no PetAppearanceStudio source found yet; generated PetModels fallback will be used.")
end
