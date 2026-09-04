--!strict
-- Adopts the authored Quaternius animal models already placed in the canonical
-- Studio world. It does not replace or duplicate them; it adds only the runtime
-- metadata consumed by the server-owned native Animator service.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local AmbientAnimalService = {}
local TEMPLATES = {
	"Pug", "Cow", "Horse", "Llama", "Pig", "Sheep", "Zebra",
	"Trex", "Velociraptor", "Triceratops", "Parasaurolophus", "Stegosaurus", "Apatosaurus",
	"Shark", "Dolphin", "Whale", "Fish1", "Fish2", "Fish3", "Manta ray",
	"Snake", "Wasp", "Frog", "Rat", "Spider",
}

local function templateFor(model: Model): string?
	for _, template in TEMPLATES do
		if model.Name == template or model.Name == template .. "_Textured" then return template end
	end
	return nil
end

local function defaultState(template: string): string
	if template == "Shark" or template == "Dolphin" or template == "Whale"
		or template == "Fish1" or template == "Fish2" or template == "Fish3"
		or template == "Manta ray" then
		return "swim"
	end
	if template == "Wasp" then return "flying" end
	return "idle"
end

local function adopt(child: Instance): boolean
	if not child:IsA("Model") then return false end
	local template = templateFor(child)
	if not template then return false end
	local controller = child:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = child
	end
	if not controller:FindFirstChildOfClass("Animator") then
		local animator = Instance.new("Animator")
		animator.Parent = controller
	end
	child:SetAttribute("RuntimeTemplate", template)
	child:SetAttribute("AnimationState", defaultState(template))
	child:SetAttribute("AnimationSpeed", 1)
	CollectionService:AddTag(child, "PocketBuddyAnimatedAnimal")
	return true
end

function AmbientAnimalService.start()
	local adopted = 0
	for _, child in Workspace:GetChildren() do
		if adopt(child) then adopted += 1 end
	end
	Workspace.ChildAdded:Connect(adopt)
	print(("[PocketBuddy] ambient animated animal packages adopted=%d"):format(adopted))
end

return AmbientAnimalService
