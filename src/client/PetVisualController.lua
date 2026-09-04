--!strict
-- Bone.Transform is presentation-only and does not reliably replicate from the
-- server. The server owns companion movement and publishes animation state;
-- each client samples the authored per-animal clips onto the replicated rig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local animationModules = ReplicatedStorage.PocketBuddy.Shared.visual.animations

type Controller = {
	state: string,
	time: number,
	bones: {[string]: Bone},
	data: any,
}

local controllers: {[Model]: Controller} = {}
local function pose(track, index: number, valueScale: number): CFrame
	local offset = (index - 1) * 7
	local v = track.values
	return CFrame.new(v[offset + 1] / valueScale, v[offset + 2] / valueScale, v[offset + 3] / valueScale)
		* CFrame.new(0, 0, 0, v[offset + 4] / valueScale, v[offset + 5] / valueScale, v[offset + 6] / valueScale, v[offset + 7] / valueScale)
end

local function sample(track, time: number, data): CFrame
	local timeScale = data.timeScale
	local times = track.times
	local count = #times
	if count == 0 then return CFrame.identity end
	if count == 1 or time <= times[1] / timeScale then return pose(track, 1, data.valueScale) end
	if time >= times[count] / timeScale then return pose(track, count, data.valueScale) end
	local upper = 2
	while upper < count and time > times[upper] / timeScale do upper += 1 end
	local lower = upper - 1
	local lowerTime = times[lower] / timeScale
	local upperTime = times[upper] / timeScale
	local alpha = math.clamp((time - lowerTime) / math.max(upperTime - lowerTime, 1e-6), 0, 1)
	return pose(track, lower, data.valueScale):Lerp(pose(track, upper, data.valueScale), alpha)
end

local function attach(model: Model): Controller?
	local template = model:GetAttribute("RuntimeTemplate")
	if type(template) ~= "string" then return nil end
	local module = animationModules:FindFirstChild(template)
	if not module or not module:IsA("ModuleScript") then return nil end
	local data = require(module)
	local found: {[string]: Bone} = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then found[descendant.Name] = descendant end
	end
	local bones: {[string]: Bone} = {}
	for _, sourceName in data.bones do
		local bone = found[sourceName]
		if not bone then return nil end
		bones[sourceName] = bone
	end
	local controller = { state = "idle", time = 0, bones = bones, data = data }
	controllers[model] = controller
	return controller
end

local function stepModel(model: Model, controller: Controller, dt: number)
	local state = string.lower(model:GetAttribute("AnimationState") or "idle")
	local clip = controller.data.clips[state] or controller.data.clips.idle
	if controller.state ~= state then
		controller.state = state
		controller.time = 0
	end
	local speed = model:GetAttribute("AnimationSpeed")
	if type(speed) ~= "number" then speed = 1 end
	controller.time = (controller.time + dt * math.clamp(speed, 0.05, 3)) % math.max(clip.duration, 0.001)
	for boneName, bone in controller.bones do
		local track = clip.tracks[boneName]
		bone.Transform = track and sample(track, controller.time, controller.data) or CFrame.identity
	end
end

local PetVisualController = {}

function PetVisualController.start()
	RunService.RenderStepped:Connect(function(dt)
		local folder = workspace:FindFirstChild("PocketBuddies")
		if folder then
			for _, child in folder:GetChildren() do
				if child:IsA("Model") then
					local controller = controllers[child] or attach(child)
					if controller then stepModel(child, controller, dt) end
				end
			end
		end
		for _, instance in CollectionService:GetTagged("PocketBuddyAnimatedAnimal") do
			if instance:IsA("Model") then
				local controller = controllers[instance] or attach(instance)
				if controller then stepModel(instance, controller, dt) end
			end
		end
		for model in controllers do
			if not model.Parent then controllers[model] = nil end
		end
	end)
end

return PetVisualController
