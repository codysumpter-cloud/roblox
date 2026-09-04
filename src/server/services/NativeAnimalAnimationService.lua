--!strict
-- Native animation owner for skinned animal rigs. Source-pack clips are stored
-- as KeyframeSequence instances and evaluated only by Roblox Animator.
local AnimationClipProvider = game:GetService("AnimationClipProvider")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local clipRoot = ReplicatedStorage:WaitForChild("PocketBuddy"):WaitForChild("Shared"):WaitForChild("native_animations")

type Controller = {
	animator: Animator,
	tracks: {[string]: AnimationTrack},
	currentState: string?,
	currentTrack: AnimationTrack?,
	reportedStates: {[string]: boolean},
}

local controllers: {[Model]: Controller} = {}
local temporaryIds: {[KeyframeSequence]: string} = {}
local unavailableSequences: {[KeyframeSequence]: boolean} = {}
local disabledModels: {[Model]: boolean} = {}
local reported: {[Model]: boolean} = {}

local function clipId(sequence: KeyframeSequence): string?
	local cached = temporaryIds[sequence]
	if cached then return cached end
	if unavailableSequences[sequence] then return nil end
	local ok, result = pcall(function()
		return AnimationClipProvider:RegisterActiveAnimationClip(sequence)
	end)
	if not ok then
		local activeError = tostring(result)
		ok, result = pcall(function()
			return AnimationClipProvider:RegisterAnimationClip(sequence)
		end)
		if not ok then
			unavailableSequences[sequence] = true
			warn(("[PocketBuddy] native clip registration failed %s: active=%s hash=%s"):format(
				sequence:GetFullName(), activeError, tostring(result)
			))
			return nil
		end
		print(("[PocketBuddy] native clip used Studio hash registration clip=%s"):format(sequence:GetFullName()))
	end
	local id = tostring(result)
	temporaryIds[sequence] = id
	return id
end

local function attach(model: Model): Controller?
	local template = model:GetAttribute("RuntimeTemplate")
	if type(template) ~= "string" then return nil end
	local package = clipRoot:FindFirstChild(template)
	if not package then return nil end
	local animationController = model:FindFirstChildOfClass("AnimationController")
	local animator = animationController and animationController:FindFirstChildOfClass("Animator")
	if not animator then
		if not reported[model] then
			reported[model] = true
			warn(("[PocketBuddy] native animator missing model=%s template=%s"):format(model:GetFullName(), template))
		end
		return nil
	end
	local tracks: {[string]: AnimationTrack} = {}
	local loaded = 0
	for _, child in package:GetChildren() do
		if child:IsA("KeyframeSequence") then
			local id = clipId(child)
			if id then
				local animation = Instance.new("Animation")
				animation.Name = child.Name
				animation.AnimationId = id
				local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
				animation:Destroy()
				if ok then
					tracks[string.lower(child.Name)] = track
					loaded += 1
				else
					warn(("[PocketBuddy] native track load failed %s/%s: %s"):format(template, child.Name, tostring(track)))
				end
			end
		end
	end
	if not next(tracks) then
		disabledModels[model] = true
		return nil
	end
	local controller = { animator = animator, tracks = tracks, currentState = nil, currentTrack = nil, reportedStates = {} }
	controllers[model] = controller
	print(("[PocketBuddy] native Animator attached model=%s template=%s tracks=%d"):format(model:GetFullName(), template, loaded))
	return controller
end

local function update(model: Model, controller: Controller)
	local requested = string.lower(model:GetAttribute("AnimationState") or "idle")
	local track = controller.tracks[requested]
		or controller.tracks.idle
		or controller.tracks.swim
		or controller.tracks.flying
		or controller.tracks.walk
	if not track then return end
	if controller.currentTrack ~= track then
		if controller.currentTrack then controller.currentTrack:Stop(0.18) end
		track:Play(0.18, 1, 1)
		controller.currentTrack = track
		controller.currentState = requested
		if not controller.reportedStates[requested] then
			controller.reportedStates[requested] = true
			print(("[PocketBuddy] native AnimationTrack playing model=%s state=%s clip=%s"):format(model:GetFullName(), requested, track.Name))
		end
	end
	local speed = model:GetAttribute("AnimationSpeed")
	track:AdjustSpeed(type(speed) == "number" and math.clamp(speed, 0.05, 3) or 1)
end

local function visit(model: Model)
	if disabledModels[model] then return end
	local controller = controllers[model] or attach(model)
	if controller then update(model, controller) end
end

local NativeAnimalAnimationService = {}

function NativeAnimalAnimationService.start()
	print(("[PocketBuddy] native animation service started packages=%d owner=server"):format(#clipRoot:GetChildren()))
	RunService.Heartbeat:Connect(function()
		local companions = workspace:FindFirstChild("PocketBuddies")
		if companions then for _, child in companions:GetChildren() do if child:IsA("Model") then visit(child) end end end
		for _, instance in CollectionService:GetTagged("PocketBuddyAnimatedAnimal") do if instance:IsA("Model") then visit(instance) end end
		for model, controller in controllers do
			if not model.Parent then
				if controller.currentTrack then controller.currentTrack:Stop(0) end
				controllers[model] = nil
				disabledModels[model] = nil
				reported[model] = nil
			end
		end
	end)
end

return NativeAnimalAnimationService
