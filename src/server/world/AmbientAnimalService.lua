--!strict
-- Server-owned ambient animal actors for the authored Roblox world. Source-pack
-- rigs remain the visuals; this service supplies stable habitat movement,
-- grounding, collision, and native animation state.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HabitatConfig = require(script.Parent.HabitatConfig)

local AmbientAnimalService = {}

local TEMPLATES = {
	"Pug", "Cow", "Horse", "Llama", "Pig", "Sheep", "Zebra",
	"Trex", "Velociraptor", "Triceratops", "Parasaurolophus", "Stegosaurus", "Apatosaurus",
	"Shark", "Dolphin", "Whale", "Fish1", "Fish2", "Fish3", "Manta ray",
	"Snake", "Wasp", "Frog", "Rat", "Spider",
}

local POND_CENTER = HabitatConfig.pond.center
local POND_PATROL_RADIUS = HabitatConfig.pond.patrolRadius

type MotionKind = "ground" | "hop" | "swim" | "fly"

type Actor = {
	model: Model,
	collider: BasePart,
	kind: MotionKind,
	center: Vector3,
	startY: number,
	radius: number,
	theta: number,
	direction: number,
	angularSpeed: number,
	elapsed: number,
	raycastParams: RaycastParams,
}

local actors: {[Model]: Actor} = {}
local started = false

local function templateFor(model: Model): string?
	for _, template in TEMPLATES do
		if model.Name == template or model.Name == template .. "_Textured" then return template end
	end
	return nil
end

local function motionFor(template: string): (MotionKind, string)
	if template == "Shark" or template == "Dolphin" or template == "Whale"
		or template == "Fish1" or template == "Fish2" or template == "Fish3"
		or template == "Manta ray" then
		return "swim", "swim"
	end
	if template == "Wasp" then return "fly", "flying" end
	if template == "Frog" then return "hop", "jump" end
	return "ground", "walk"
end

local function stableHash(value: string): number
	local result = 17
	for index = 1, #value do
		result = (result * 31 + string.byte(value, index)) % 104729
	end
	return result
end

local function belongsToGameplayPet(model: Model): boolean
	if model:GetAttribute("OwnerUserId") ~= nil or model:GetAttribute("PartyOwnerUserId") ~= nil then
		return true
	end
	local buddies = Workspace:FindFirstChild("PocketBuddies")
	return buddies ~= nil and model:IsDescendantOf(buddies)
end

local function ensureAnimator(model: Model)
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
end

local function stabilize(model: Model): BasePart?
	local collider = model.PrimaryPart or model:FindFirstChild("RootPart", true)
	if collider and not collider:IsA("BasePart") then collider = nil end
	if not collider then collider = model:FindFirstChildWhichIsA("BasePart", true) end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
			descendant.CanCollide = descendant == collider
			descendant.CanTouch = false
			descendant.CanQuery = descendant == collider
			descendant.Massless = true
			descendant.Anchored = true
		end
	end
	return collider
end

local function adopt(instance: Instance): boolean
	if not instance:IsA("Model") or actors[instance] or belongsToGameplayPet(instance) then return false end
	if instance:FindFirstChildOfClass("Humanoid") then return false end
	local template = templateFor(instance)
	if not template then return false end

	local kind, animationState = motionFor(template)
	local pivot = instance:GetPivot()
	local hash = stableHash(instance:GetFullName())
	local phase = math.rad(hash % 360)
	local direction = if hash % 2 == 0 then 1 else -1
	local speed = 2.2 + (hash % 15) / 10
	local radius = if kind == "swim" then 8 + hash % (POND_PATROL_RADIUS - 7) else 5 + hash % 8
	local center = pivot.Position - Vector3.new(math.cos(phase) * radius, 0, math.sin(phase) * radius)
	local startY = pivot.Position.Y
	if kind == "swim" then
		center = POND_CENTER
		startY = POND_CENTER.Y + ((hash % 5) - 2) * 0.45
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { instance }
	params.RespectCanCollide = true

	ensureAnimator(instance)
	local collider = stabilize(instance)
	if not collider then return false end
	instance:SetAttribute("RuntimeTemplate", template)
	instance:SetAttribute("AnimationState", animationState)
	instance:SetAttribute("AnimationSpeed", math.clamp(speed / 3, 0.7, 1.35))
	instance:SetAttribute("AmbientActor", true)
	instance:SetAttribute("AmbientMoving", true)
	instance:SetAttribute("AmbientHabitat", if kind == "swim" then "Pond" else "Meadow")
	CollectionService:AddTag(instance, "PocketBuddyAnimatedAnimal")

	actors[instance] = {
		model = instance,
		collider = collider,
		kind = kind,
		center = center,
		startY = startY,
		radius = radius,
		theta = phase,
		direction = direction,
		angularSpeed = speed / radius,
		elapsed = 0,
		raycastParams = params,
	}
	return true
end

local function groundSurface(actor: Actor, position: Vector3): number
	local rayOrigin = Vector3.new(position.X, actor.startY + 80, position.Z)
	local result = Workspace:Raycast(rayOrigin, Vector3.new(0, -200, 0), actor.raycastParams)
	if result then return result.Position.Y end
	return actor.startY
end

local function groundModel(actor: Actor, surfaceY: number)
	local bounds, size = actor.model:GetBoundingBox()
	local bottom = bounds.Position.Y - size.Y * 0.5
	actor.model:PivotTo(actor.model:GetPivot() + Vector3.new(0, surfaceY - bottom, 0))
end

local function obstacleAhead(actor: Actor, position: Vector3, tangent: Vector3): boolean
	if actor.kind == "swim" or actor.kind == "fly" then return false end
	local halfHeight = math.max(actor.collider.Size.Y * 0.4, 0.75)
	local distance = math.max(actor.collider.Size.Z * 0.55, 1.5)
	local result = Workspace:Raycast(position + Vector3.new(0, halfHeight, 0), tangent * distance, actor.raycastParams)
	return result ~= nil and result.Instance.CanCollide
end

local function updateActor(actor: Actor, deltaTime: number)
	local model = actor.model
	if not model.Parent then
		actors[model] = nil
		return
	end

	actor.elapsed += deltaTime
	local nextTheta = actor.theta + deltaTime * actor.angularSpeed * actor.direction
	local nextPosition = actor.center + Vector3.new(math.cos(nextTheta) * actor.radius, 0, math.sin(nextTheta) * actor.radius)
	local tangent = Vector3.new(-math.sin(nextTheta) * actor.direction, 0, math.cos(nextTheta) * actor.direction)
	if obstacleAhead(actor, nextPosition, tangent) then
		actor.direction *= -1
		return
	end
	actor.theta = nextTheta

	if actor.kind == "ground" then
		local surfaceY = groundSurface(actor, nextPosition)
		nextPosition = Vector3.new(nextPosition.X, surfaceY, nextPosition.Z)
		model:PivotTo(CFrame.lookAt(nextPosition, nextPosition + tangent))
		groundModel(actor, surfaceY)
	elseif actor.kind == "hop" then
		local surfaceY = groundSurface(actor, nextPosition)
		local hop = math.max(0, math.sin(actor.elapsed * 4.5)) * 1.1
		nextPosition = Vector3.new(nextPosition.X, surfaceY + hop, nextPosition.Z)
		model:PivotTo(CFrame.lookAt(nextPosition, nextPosition + tangent))
		groundModel(actor, surfaceY + hop)
	elseif actor.kind == "fly" then
		nextPosition = Vector3.new(nextPosition.X, actor.startY + math.sin(actor.elapsed * 2.2) * 1.4, nextPosition.Z)
		model:PivotTo(CFrame.lookAt(nextPosition, nextPosition + tangent))
	else
		nextPosition = Vector3.new(nextPosition.X, actor.startY + math.sin(actor.elapsed * 1.4) * 0.35, nextPosition.Z)
		model:PivotTo(CFrame.lookAt(nextPosition, nextPosition + tangent))
	end
end

function AmbientAnimalService.start()
	if started then return end
	started = true

	local adopted = 0
	for _, descendant in Workspace:GetDescendants() do
		if adopt(descendant) then adopted += 1 end
	end
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") then task.defer(adopt, descendant) end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator < 0.05 then return end
		local step = math.min(accumulator, 0.15)
		accumulator = 0
		for _, actor in actors do updateActor(actor, step) end
	end)

	print(("[PocketBuddy] ambient animal actors adopted=%d movement=server-owned stable-collision=enabled"):format(adopted))
end

return AmbientAnimalService
