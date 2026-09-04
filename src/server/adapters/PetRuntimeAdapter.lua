--!strict
local PetAssetLoader = require(script.Parent.PetAssetLoader)
local PetAssetRegistry = require(script.Parent.PetAssetRegistry)
local PetRuntimeAdapter = {}
local warnedMissing = {}
local diagnosticsEmitted = {}
local groundingDiagnosticsEmitted = {}
local GROUND_CLEARANCE = 0.03

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

local function findRoot(model: Model): BasePart?
	if model.PrimaryPart then return model.PrimaryPart end
	for _, name in { "HumanoidRootPart", "RootPart", "Root", "root", "Armature" } do
		local candidate = model:FindFirstChild(name, true)
		if candidate and candidate:IsA("BasePart") then return candidate end
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function templateFor(key: string): Model?
	local template = PetAssetLoader.get(key)
	return template
end

local function boundsText(size: Vector3): string
	return ("%.2f,%.2f,%.2f"):format(size.X, size.Y, size.Z)
end

local function normalize(model: Model, key: string): (Vector3, Vector3, number)
	local _, sourceSize = model:GetBoundingBox()
	local config = PetAssetRegistry[key]
	local target = config and config.targetLargestDimension
	local largest = math.max(sourceSize.X, sourceSize.Y, sourceSize.Z)
	local scale = 1
	if target and target > 0 and largest > 0 then
		scale = target / largest
		if math.abs(scale - 1) > 0.01 then
			local ok = pcall(function() model:ScaleTo(scale) end)
			if not ok then
				warn(("[PocketBuddy] could not normalize %s model scale; using source dimensions"):format(key))
				scale = 1
			end
		end
	end
	local _, runtimeSize = model:GetBoundingBox()
	return sourceSize, runtimeSize, scale
end

local function cacheBottomOffset(model: Model): number
	local bounds, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local bottomY = bounds.Position.Y - size.Y / 2
	local offset = pivot.Position.Y - bottomY
	model:SetAttribute("GroundBottomOffset", offset)
	return offset
end

local function emitDiagnostics(key: string, found: boolean, sourceSize: Vector3, runtimeSize: Vector3, scale: number)
	if diagnosticsEmitted[key] then return end
	diagnosticsEmitted[key] = true
	local config = PetAssetRegistry[key]
	local appearance = config and config.appearance or "generated-placeholder"
	print(("[PocketBuddy] template=%s"):format(key))
	print(("[PocketBuddy] assetFound=%s"):format(tostring(found)))
	print(("[PocketBuddy] sourceBounds=%s"):format(boundsText(sourceSize)))
	print(("[PocketBuddy] runtimeBounds=%s"):format(boundsText(runtimeSize)))
	print(("[PocketBuddy] scale=%.6f"):format(scale))
	print(("[PocketBuddy] appearance=%s"):format(appearance))
end

function PetRuntimeAdapter.buildPlaceholder(pet): Model
	local model = Instance.new("Model")
	model.Name = "Pet_" .. pet.id
	model:SetAttribute("GeneratedPlaceholder", true)
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
	-- Keep the generated assembly together when a party mode enables physics. The
	-- welds do not make hub companions physical; prepare() still anchors them.
	for _, descendant in model:GetChildren() do
		if descendant:IsA("BasePart") and descendant ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = root
		end
	end
	return model
end

function PetRuntimeAdapter.build(pet): (Model, boolean)
	local key = type(pet.runtimeTemplate) == "string" and pet.runtimeTemplate or "Pug"
	local template = templateFor(key)
	if template then
		local model = template:Clone()
		model.Name = "Pet_" .. pet.id
		model:SetAttribute("PetId", pet.id)
		model:SetAttribute("RuntimeTemplate", key)
		local root = findRoot(model)
		if root then model.PrimaryPart = root end
		if root then
			local sourceSize, runtimeSize, scale = normalize(model, key)
			cacheBottomOffset(model)
			emitDiagnostics(key, true, sourceSize, runtimeSize, scale)
			return model, true
		end
		model:Destroy()
		if not warnedMissing[key] then
			warnedMissing[key] = true
			warn(("[PocketBuddy] runtime pet asset %s has no BasePart root; using generated placeholder"):format(key))
		end
	end
	if not warnedMissing[key] then
		warnedMissing[key] = true
		warn(("[PocketBuddy] runtime pet asset missing at ServerStorage/PocketBuddyAssets/Pets/%s; using generated placeholder"):format(key))
	end
	local fallback = PetRuntimeAdapter.buildPlaceholder(pet)
	fallback:SetAttribute("RuntimeTemplate", key)
	local _, fallbackSize = fallback:GetBoundingBox()
	cacheBottomOffset(fallback)
	emitDiagnostics(key, false, fallbackSize, fallbackSize, 1)
	return fallback, false
end

function PetRuntimeAdapter.groundedCFrame(model: Model, character: Model, desiredXZ: Vector3, facing: Vector3): CFrame?
	local characterRoot = character:FindFirstChild("HumanoidRootPart")
	if not characterRoot or not characterRoot:IsA("BasePart") then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local excluded: { Instance } = { character, model }
	for _, name in { "PocketBuddies", "PocketBuddyHub", "PocketBuddyRuntimeArt" } do
		local instance = workspace:FindFirstChild(name)
		if instance then table.insert(excluded, instance) end
	end
	params.FilterDescendantsInstances = excluded
	local origin = Vector3.new(desiredXZ.X, characterRoot.Position.Y + 50, desiredXZ.Z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -250, 0), params)
	if not hit then return nil end
	local bottomOffset = model:GetAttribute("GroundBottomOffset")
	if type(bottomOffset) ~= "number" then bottomOffset = cacheBottomOffset(model) end
	local direction = Vector3.new(facing.X, 0, facing.Z)
	if direction.Magnitude < 0.001 then direction = Vector3.new(0, 0, -1) else direction = direction.Unit end
	local finalPosition = Vector3.new(desiredXZ.X, hit.Position.Y + bottomOffset + GROUND_CLEARANCE, desiredXZ.Z)
	local result = CFrame.lookAt(finalPosition, finalPosition + direction)
	local key = model:GetAttribute("RuntimeTemplate")
	if type(key) == "string" and not groundingDiagnosticsEmitted[key] then
		groundingDiagnosticsEmitted[key] = true
		local bounds, size = model:GetBoundingBox()
		print(("[PocketBuddy] %s runtime bounds=%s pivotY=%.3f bottomRelativeToPivot=%.3f groundY=%.3f finalPivotY=%.3f"):format(
			key, boundsText(size), model:GetPivot().Position.Y, bottomOffset, hit.Position.Y, finalPosition.Y
		))
	end
	return result
end

function PetRuntimeAdapter.prepare(model: Model)
	local controller = model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = model
	end
	if not controller:FindFirstChildOfClass("Animator") then
		local animator = Instance.new("Animator")
		animator.Parent = controller
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- Hub companions are presentation-only. Anchor only the resolved root on a
			-- real rig so Motor6D/Bone animation remains free to pose other parts.
			if model:GetAttribute("GeneratedPlaceholder") == true then descendant.Anchored = true end
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	local root = findRoot(model)
	if root and model:GetAttribute("GeneratedPlaceholder") ~= true then root.Anchored = true end
	if root then model.PrimaryPart = root end
end

function PetRuntimeAdapter.setPhysics(model: Model, enabled: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = not enabled
			descendant.CanCollide = enabled and descendant.Name ~= "Root"
			descendant.CanTouch = enabled
			descendant.CanQuery = enabled
			if enabled then
				-- Server ownership makes impulses and elimination decisions authoritative.
				pcall(function() descendant:SetNetworkOwner(nil) end)
			end
		end
	end
end

return PetRuntimeAdapter
