--!strict
local PetAnimationConfig = require(script.Parent.PetAnimationConfig)

local PetAnimationAdapter = {}
local active: {[Model]: {state: string, track: AnimationTrack?}} = {}
local warnedMissing = false
local warnedController: {[Model]: boolean} = {}
local animationIds: {[string]: string} = PetAnimationConfig

local function getAnimator(model: Model): Animator?
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if animator then return animator end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
	if not controller and not humanoid then
		if not warnedController[model] then
			warnedController[model] = true
			warn(("[PocketBuddy] pet %s has no Humanoid/AnimationController; running without animation"):format(model.Name))
		end
		return nil
	end
	local parent = humanoid or controller
	animator = parent and parent:FindFirstChildOfClass("Animator")
	if not animator and parent then
		animator = Instance.new("Animator")
		animator.Parent = parent
	end
	return animator
end

local function assetIdFor(state: string): string?
	local value = animationIds[state]
	if type(value) ~= "string" or value == "" then return nil end
	if string.sub(value, 1, 13) == "rbxassetid://" then return value end
	return "rbxassetid://" .. value
end

local function warnMissingIds()
	if warnedMissing then return end
	local missing = {}
	for _, state in { "idle", "walk", "run", "jump" } do
		if not assetIdFor(state) then table.insert(missing, state) end
	end
	if #missing > 0 then
		warnedMissing = true
		warn(("[PocketBuddy] Pug animation IDs missing (publish and set PetAnimationConfig.lua): %s"):format(table.concat(missing, ", ")))
	end
end

function PetAnimationAdapter.setState(model: Model, state: string, speed: number?)
	local current = active[model]
	if current and current.state == state then
		if current.track then current.track:AdjustSpeed(speed or 1) end
		return
	end
	if current and current.track then current.track:Stop(0.15) end
	local id = assetIdFor(state)
	if not id then
		warnMissingIds()
		active[model] = { state = state, track = nil }
		return
	end
	local animator = getAnimator(model)
	if not animator then
		active[model] = { state = state, track = nil }
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	animation:Destroy()
	if not ok or not track then
		warn(("[PocketBuddy] could not load pet animation state %s for %s"):format(state, model.Name))
		active[model] = { state = state, track = nil }
		return
	end
	track.Looped = state ~= "jump"
	track.Priority = state == "jump" and Enum.AnimationPriority.Action or Enum.AnimationPriority.Movement
	track:Play(0.15, 1, speed or 1)
	active[model] = { state = state, track = track }
end

function PetAnimationAdapter.stateForSpeed(speed: number, grounded: boolean): string
	if not grounded then return "jump" end
	if speed >= 12 then return "run" end
	if speed >= 1 then return "walk" end
	return "idle"
end

function PetAnimationAdapter.clear(model: Model)
	local current = active[model]
	if current and current.track then current.track:Stop(0) end
	active[model] = nil
	warnedController[model] = nil
end

return PetAnimationAdapter
