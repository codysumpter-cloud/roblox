--!strict
local AnimationData = require(script.Parent.PugAnimationData)
local PugBoneMap = require(script.Parent.PugBoneMap)

type Track = {
	times: {number},
	values: {number},
}

type Clip = {
	duration: number,
	tracks: {[string]: Track},
}

type Transition = {
	from: {[string]: CFrame},
	elapsed: number,
	duration: number,
}

type Controller = {
	enabled: boolean,
	state: string,
	time: number,
	speed: number,
	bones: {[string]: Bone},
	base: {[string]: CFrame},
	transition: Transition?,
}

local clips = AnimationData.clips :: {[string]: Clip}
local valueScale = AnimationData.valueScale
local timeScale = AnimationData.timeScale
local active: {[Model]: Controller} = {}

local function clipForState(state: string): Clip
	-- Walk is the normal companion pace. WalkSlow remains available for callers
	-- that want a deliberately sleepy animation without changing the state API.
	return clips[state] or clips.idle
end

local function collectController(model: Model): Controller
	local isPug = model:GetAttribute("RuntimeTemplate") == "Pug"
	local discovered: {[string]: Bone} = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then discovered[descendant.Name] = descendant end
	end
	local bones: {[string]: Bone} = {}
	local base: {[string]: CFrame} = {}
	local missing = {}
	if isPug then
		for sourceName, robloxName in PugBoneMap do
			local bone = discovered[robloxName]
			if bone then
				bones[sourceName] = bone
				base[sourceName] = bone.Transform
			else
				table.insert(missing, sourceName)
			end
		end
		print(("[PocketBuddy] Pug animation bones mapped=%d/%d"):format(#AnimationData.bones - #missing, #AnimationData.bones))
		if #missing > 0 then warn("[PocketBuddy] missing Pug animation bones: " .. table.concat(missing, ", ")) end
	end
	local controller: Controller = {
		enabled = isPug and #missing == 0,
		state = "idle",
		time = 0,
		speed = 1,
		bones = bones,
		base = base,
		transition = nil,
	}
	active[model] = controller
	return controller
end

local function poseFromValues(track: Track, index: number): CFrame
	local offset = (index - 1) * 7
	local values = track.values
	return CFrame.new(
		values[offset + 1] / valueScale,
		values[offset + 2] / valueScale,
		values[offset + 3] / valueScale
	) * CFrame.new(0, 0, 0,
		values[offset + 4] / valueScale,
		values[offset + 5] / valueScale,
		values[offset + 6] / valueScale,
		values[offset + 7] / valueScale
	)
end

local function sampleTrack(track: Track, time: number): CFrame
	local times = track.times
	local count = #times
	if count == 0 then return CFrame.identity end
	if count == 1 or time <= times[1] / timeScale then
		return poseFromValues(track, 1)
	end
	if time >= times[count] / timeScale then
		return poseFromValues(track, count)
	end

	local upper = 2
	while upper < count and time > times[upper] / timeScale do
		upper += 1
	end
	local lower = upper - 1
	local lowerTime = times[lower] / timeScale
	local upperTime = times[upper] / timeScale
	local alpha = math.clamp((time - lowerTime) / math.max(upperTime - lowerTime, 1e-6), 0, 1)
	return poseFromValues(track, lower):Lerp(poseFromValues(track, upper), alpha)
end

local function targetPose(controller: Controller, clip: Clip, boneName: string): CFrame
	local base = controller.base[boneName] or CFrame.identity
	local track = clip.tracks[boneName]
	if not track then return base end
	return base * sampleTrack(track, controller.time)
end

local PetAnimationAdapter = {}

function PetAnimationAdapter.setState(model: Model, state: string, speed: number?)
	local normalized = string.lower(state)
	if not clips[normalized] then normalized = "idle" end
	local controller = active[model] or collectController(model)
	local nextSpeed = math.clamp(speed or 1, 0.05, 3)
	if controller.state == normalized then
		controller.speed = nextSpeed
		return
	end

	local from: {[string]: CFrame} = {}
	for boneName, bone in controller.bones do
		from[boneName] = bone.Transform
	end
	controller.state = normalized
	controller.time = 0
	controller.speed = nextSpeed
	controller.transition = {
		from = from,
		elapsed = 0,
		duration = normalized == "jump" and 0.10 or 0.18,
	}
end

function PetAnimationAdapter.step(model: Model, dt: number)
	local controller = active[model]
	if not controller or not controller.enabled then return end
	local clip = clipForState(controller.state)
	if clip.duration > 0 then
		local nextTime = controller.time + math.max(dt, 0) * controller.speed
		if controller.state == "jump" then
			controller.time = math.min(nextTime, clip.duration)
		else
			controller.time = nextTime % clip.duration
		end
	end

	local transition = controller.transition
	if transition then transition.elapsed += math.max(dt, 0) end
	local alpha = transition and math.clamp(transition.elapsed / transition.duration, 0, 1) or 1
	for boneName, bone in controller.bones do
		local target = targetPose(controller, clip, boneName)
		if transition then
			bone.Transform = (transition.from[boneName] or controller.base[boneName] or CFrame.identity):Lerp(target, alpha)
		else
			bone.Transform = target
		end
	end
	if transition and alpha >= 1 then controller.transition = nil end
end

function PetAnimationAdapter.stateForSpeed(speed: number, grounded: boolean): string
	if not grounded then return "jump" end
	if speed < 0.35 then return "idle" end
	if speed < 3 then return "walkslow" end
	if speed < 10 then return "walk" end
	return "run"
end

function PetAnimationAdapter.clear(model: Model)
	local controller = active[model]
	if controller then
		for boneName, bone in controller.bones do
			bone.Transform = controller.base[boneName] or CFrame.identity
		end
	end
	active[model] = nil
end

return PetAnimationAdapter
