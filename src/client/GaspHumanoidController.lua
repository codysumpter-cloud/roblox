--!strict
-- Roblox adapter for the shared Prismtek GASP semantic contract.
-- It only takes ownership when a usable set of published Animation objects is
-- present under ReplicatedStorage/PocketBuddy/HumanoidAssets/Animations.
-- Player physics stays authoritative; the promoted GASP clips are in-place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GaspManifest = require(ReplicatedStorage.PocketBuddy.Shared.avatar.GaspManifest)

local GaspHumanoidController = {}
local started = false

type TrackMap = {[string]: AnimationTrack}

local function normalized(value: string): string
	return string.lower((string.gsub(value, "[%s%-]+", "_")))
end

local function animationFor(assets: Folder, semantic: string): Animation?
	local direct = assets:FindFirstChild(semantic)
	if direct and direct:IsA("Animation") then return direct end
	local sourceName = GaspManifest.clips[semantic]
	if type(sourceName) ~= "string" then return nil end
	local wanted = normalized(sourceName)
	for _, item in assets:GetChildren() do
		if item:IsA("Animation") and normalized(item.Name) == wanted then return item end
		if item:IsA("Animation") and item:GetAttribute("Semantic") == semantic then return item end
	end
	return nil
end

local function stopTracks(tracks: TrackMap, except: AnimationTrack?, fade: number)
	for _, track in tracks do
		if track ~= except and track.IsPlaying then track:Stop(fade) end
	end
end

local function bindCharacter(character: Model, assets: Folder)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid or not humanoid:IsA("Humanoid") then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animations: {[string]: Animation} = {}
	for semantic in GaspManifest.clips do
		local animation = animationFor(assets, semantic)
		if animation then animations[semantic] = animation end
	end
	for _, required in GaspManifest.requiredLocomotion do
		if not animations[required] then
			character:SetAttribute("PocketBuddyGaspReady", false)
			return
		end
	end

	local tracks: TrackMap = {}
	for semantic, animation in animations do
		local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
		if ok and track then
			tracks[semantic] = track
			track.Looped = GaspManifest.looping[semantic] == true
			track.Priority = if semantic == "idle" then Enum.AnimationPriority.Idle
				elseif GaspManifest.looping[semantic] then Enum.AnimationPriority.Movement
				else Enum.AnimationPriority.Action
		end
	end
	for _, required in GaspManifest.requiredLocomotion do
		if not tracks[required] then character:SetAttribute("PocketBuddyGaspReady", false); return end
	end

	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then animate.Disabled = true end
	character:SetAttribute("PocketBuddyGaspReady", true)
	character:SetAttribute("PocketBuddyAnimationProvider", "GASP_UEFN")

	local currentLoop: AnimationTrack? = nil
	local currentSemantic = ""
	local lastMoving = false
	local lastMove = Vector3.zero
	local lastGrounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local actionUntil = 0

	local function playOneShot(semantic: string, fade: number?)
		local track = tracks[semantic]
		if not track then return end
		stopTracks(tracks, track, fade or 0.08)
		track.TimePosition = 0
		track:Play(fade or 0.08, 1, 1)
		actionUntil = os.clock() + math.max(track.Length, 0.18)
	end

	local function playLoop(semantic: string, speedScale: number?)
		local track = tracks[semantic]
		if not track then return end
		if currentLoop ~= track then
			if currentLoop and currentLoop.IsPlaying then currentLoop:Stop(0.12) end
			track:Play(0.12, 1, speedScale or 1)
			currentLoop = track
			currentSemantic = semantic
		elseif speedScale then
			track:AdjustSpeed(speedScale)
		end
	end

	local connection: RBXScriptConnection?
	connection = RunService.RenderStepped:Connect(function()
		if character.Parent == nil or humanoid.Health <= 0 then
			if connection then connection:Disconnect() end
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then return end
		local state = humanoid:GetState()
		local velocity = root.AssemblyLinearVelocity
		local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local move = humanoid.MoveDirection
		local moving = move.Magnitude > 0.08

		if state == Enum.HumanoidStateType.Jumping then
			if currentSemantic ~= "jump" then playOneShot("jump", 0.06); currentSemantic = "jump" end
		elseif not grounded or state == Enum.HumanoidStateType.Freefall then
			playLoop("fall", 1)
		elseif not lastGrounded and grounded then
			playOneShot("land", 0.05)
			currentSemantic = "land"
		elseif os.clock() >= actionUntil then
			if moving and not lastMoving and tracks.start then playOneShot("start", 0.08) end
			if not moving and lastMoving and tracks.stop then playOneShot("stop", 0.08) end
			if moving and lastMove.Magnitude > 0.08 then
				local dot = math.clamp(lastMove.Unit:Dot(move.Unit), -1, 1)
				if dot < -0.15 then
					local crossY = lastMove.Unit:Cross(move.Unit).Y
					local semantic = if crossY >= 0 then "pivot_left" else "pivot_right"
					if tracks[semantic] then playOneShot(semantic, 0.06) end
				end
			end
			if os.clock() >= actionUntil then
				if not moving or horizontalSpeed < 0.35 then
					playLoop("idle", 1)
				else
					local walkSpeed = math.max(humanoid.WalkSpeed, 1)
					local ratio = horizontalSpeed / walkSpeed
					if ratio < 0.48 then playLoop("walk", math.clamp(ratio / 0.48, 0.65, 1.3))
					elseif ratio < 0.86 then playLoop("jog", math.clamp(ratio / 0.72, 0.8, 1.25))
					else playLoop("sprint", math.clamp(ratio, 0.9, 1.35)) end
				end
			end
		end
		lastMoving = moving
		lastGrounded = grounded
		if moving then lastMove = move end
	end)
end

function GaspHumanoidController.start()
	if started then return end
	started = true
	local assets = ReplicatedStorage:WaitForChild("PocketBuddy"):WaitForChild("HumanoidAssets"):WaitForChild("Animations") :: Folder
	local player = Players.LocalPlayer
	if player.Character then task.spawn(bindCharacter, player.Character, assets) end
	player.CharacterAdded:Connect(function(character) task.spawn(bindCharacter, character, assets) end)
end

return GaspHumanoidController
