--!strict
-- Adopts the authored Quaternius animal models already placed in the canonical
-- Studio world. It does not replace or duplicate them; it adds only the runtime
-- metadata consumed by the client animation package.
local CollectionService = game:GetService("CollectionService")

local AmbientAnimalService = {}
local TEMPLATES = { "Pug", "Cow", "Horse", "Llama", "Pig", "Sheep", "Zebra" }

local function templateFor(model: Model): string?
	for _, template in TEMPLATES do
		if model.Name == template or model.Name == template .. "_Textured" then return template end
	end
	return nil
end

function AmbientAnimalService.start()
	local adopted = 0
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") then
			local template = templateFor(child)
			if template then
				child:SetAttribute("RuntimeTemplate", template)
				child:SetAttribute("AnimationState", "idle")
				child:SetAttribute("AnimationSpeed", 1)
				CollectionService:AddTag(child, "PocketBuddyAnimatedAnimal")
				adopted += 1
			end
		end
	end
	print(("[PocketBuddy] ambient animated animal packages adopted=%d"):format(adopted))
end

return AmbientAnimalService
