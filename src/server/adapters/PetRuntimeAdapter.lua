--!strict
local PetRuntimeAdapter = {}

local paletteColors = {
	sky = Color3.fromRGB(106, 220, 245),
	peach = Color3.fromRGB(244, 174, 132),
	mint = Color3.fromRGB(139, 226, 164),
	berry = Color3.fromRGB(206, 135, 205),
}

local function part(parent: Instance, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

function PetRuntimeAdapter.buildPlaceholder(pet): Model
	local model = Instance.new("Model")
	model.Name = "Pet_" .. pet.id
	model:SetAttribute("PetId", pet.id)
	local color = paletteColors[pet.parts.palette] or Color3.fromRGB(180, 210, 230)

	local root = part(model, "Root", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), color)
	root.Transparency = 1
	model.PrimaryPart = root

	local bodyScale = pet.parts.body == "chunky" and 1.15 or pet.parts.body == "tiny" and 0.82 or 1
	part(model, "Body", Vector3.new(2.1, 1.7, 1.7) * bodyScale, CFrame.new(), color, Enum.PartType.Ball)
	part(model, "Head", Vector3.new(1.45, 1.3, 1.35), CFrame.new(0, 0.65, -1.25), color, Enum.PartType.Ball)
	part(model, "LeftEye", Vector3.new(0.16, 0.22, 0.1), CFrame.new(-0.31, 0.82, -1.92), Color3.fromRGB(25, 28, 35))
	part(model, "RightEye", Vector3.new(0.16, 0.22, 0.1), CFrame.new(0.31, 0.82, -1.92), Color3.fromRGB(25, 28, 35))

	local legHeight = pet.parts.legs == "long" and 0.95 or pet.parts.legs == "stubby" and 0.48 or 0.68
	for _, x in { -0.65, 0.65 } do
		for _, z in { -0.45, 0.55 } do
			part(model, "Leg", Vector3.new(0.34, legHeight, 0.38), CFrame.new(x, -0.82, z), color)
		end
	end

	local tailLength = pet.parts.tail == "otter" and 1.6 or pet.parts.tail == "raccoon" and 1.35 or 0.9
	part(model, "Tail", Vector3.new(0.28, 0.28, tailLength), CFrame.new(0, -0.1, 1.28 + tailLength / 2), color)
	return model
end

function PetRuntimeAdapter.prepare(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

return PetRuntimeAdapter
