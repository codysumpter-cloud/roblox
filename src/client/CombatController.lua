--!strict
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CombatConfig = require(ReplicatedStorage.PocketBuddy.Shared.core.combat.CombatConfig)
local TargetingRules = require(ReplicatedStorage.PocketBuddy.Shared.core.combat.TargetingRules)

local CombatController = {}
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("PocketBuddyRemotes")
local CombatIntent = remotes:WaitForChild("CombatIntent") :: RemoteEvent
local CombatEvent = remotes:WaitForChild("CombatEvent") :: RemoteEvent

local started = false
local hardLock = false
local currentTarget: Player? = nil
local stunnedUntil = 0

local highlight = Instance.new("Highlight")
highlight.Name = "CombatTargetHighlight"
highlight.Enabled = false
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.FillTransparency = 1
highlight.OutlineTransparency = 0.15
highlight.Parent = Workspace

local function characterParts(targetPlayer: Player): (Model?, Humanoid?, BasePart?)
	local character = targetPlayer.Character
	if not character then return nil, nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return character, humanoid, nil end
	return character, humanoid, root
end

local function hasLineOfSight(targetCharacter: Model, targetRoot: BasePart): boolean
	local camera = Workspace.CurrentCamera
	local ownCharacter = player.Character
	if not camera then return false end
	local origin = camera.CFrame.Position
	local delta = targetRoot.Position - origin
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if ownCharacter then { ownCharacter } else {}
	local hit = Workspace:Raycast(origin, delta, params)
	return hit == nil or hit.Instance:IsDescendantOf(targetCharacter)
end

local function targetScore(targetPlayer: Player, useHardCone: boolean): number?
	local camera = Workspace.CurrentCamera
	if not camera or targetPlayer == player then return nil end
	local character, _, root = characterParts(targetPlayer)
	if not character or not root then return nil end

	local delta = root.Position - camera.CFrame.Position
	local distance = delta.Magnitude
	if distance < 0.001 then return nil end
	local dot = math.clamp(camera.CFrame.LookVector:Dot(delta.Unit), -1, 1)
	local angleDegrees = math.deg(math.acos(dot))
	local screenPoint, onScreen = camera:WorldToViewportPoint(root.Position)
	if not onScreen and not useHardCone then return nil end
	local viewport = camera.ViewportSize
	local center = viewport * 0.5
	local screenDistance = (Vector2.new(screenPoint.X, screenPoint.Y) - center).Magnitude / math.max(center.Magnitude, 1)

	return TargetingRules.score({
		distance = distance,
		angleDegrees = angleDegrees,
		screenDistance = screenDistance,
		hasLineOfSight = hasLineOfSight(character, root),
		isCurrent = currentTarget == targetPlayer,
	}, CombatConfig.Targeting, useHardCone)
end

local function orderedTargets(useHardCone: boolean): {Player}
	local scored = {}
	for _, targetPlayer in Players:GetPlayers() do
		local score = targetScore(targetPlayer, useHardCone)
		if score then table.insert(scored, { player = targetPlayer, score = score }) end
	end
	table.sort(scored, function(a, b) return a.score > b.score end)
	local result = {}
	for _, entry in scored do table.insert(result, entry.player) end
	return result
end

local function bestTarget(useHardCone: boolean): Player?
	return orderedTargets(useHardCone)[1]
end

local function setTarget(targetPlayer: Player?)
	currentTarget = targetPlayer
	local character = targetPlayer and targetPlayer.Character
	highlight.Adornee = character
	highlight.Enabled = character ~= nil
end

local function faceTarget(targetPlayer: Player?, immediate: boolean)
	if not targetPlayer then return end
	local _, _, ownRoot = characterParts(player)
	local _, _, targetRoot = characterParts(targetPlayer)
	if not ownRoot or not targetRoot then return end
	local lookAt = Vector3.new(targetRoot.Position.X, ownRoot.Position.Y, targetRoot.Position.Z)
	if (lookAt - ownRoot.Position).Magnitude < 0.01 then return end
	local goal = CFrame.lookAt(ownRoot.Position, lookAt)
	if immediate then
		ownRoot.CFrame = goal
	else
		ownRoot.CFrame = ownRoot.CFrame:Lerp(goal, 0.22)
	end
end

local function refreshTarget()
	if hardLock then
		if not currentTarget or targetScore(currentTarget, true) == nil then setTarget(bestTarget(true)) end
	else
		setTarget(bestTarget(false))
	end
end

local function canLocalAct(): boolean
	return os.clock() >= stunnedUntil
end

local function attackAction(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	if not canLocalAct() then return Enum.ContextActionResult.Sink end
	refreshTarget()
	faceTarget(currentTarget, true)
	CombatIntent:FireServer({ action = "light" })
	return Enum.ContextActionResult.Sink
end

local function launcherAction(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	if not canLocalAct() then return Enum.ContextActionResult.Sink end
	refreshTarget()
	faceTarget(currentTarget, true)
	CombatIntent:FireServer({ action = "launcher" })
	return Enum.ContextActionResult.Sink
end

local function blockAction(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin and canLocalAct() then
		CombatIntent:FireServer({ action = "block_start" })
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		CombatIntent:FireServer({ action = "block_end" })
	end
	return Enum.ContextActionResult.Sink
end

local function dashAction(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	if not canLocalAct() then return Enum.ContextActionResult.Sink end
	local _, humanoid, root = characterParts(player)
	if not humanoid or not root then return Enum.ContextActionResult.Sink end
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then direction = root.CFrame.LookVector end
	CombatIntent:FireServer({ action = "dash", direction = direction })
	return Enum.ContextActionResult.Sink
end

local function lockAction(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	hardLock = not hardLock
	if hardLock then setTarget(bestTarget(true)) else setTarget(bestTarget(false)) end
	return Enum.ContextActionResult.Sink
end

local function cycleAction(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	local targets = orderedTargets(true)
	if #targets == 0 then
		hardLock = false
		setTarget(nil)
		return Enum.ContextActionResult.Sink
	end
	hardLock = true
	local nextIndex = 1
	for index, targetPlayer in targets do
		if targetPlayer == currentTarget then nextIndex = index % #targets + 1 break end
	end
	setTarget(targets[nextIndex])
	return Enum.ContextActionResult.Sink
end

local function fovKick(amount: number)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local base = camera.FieldOfView
	TweenService:Create(camera, TweenInfo.new(0.05), { FieldOfView = base + amount }):Play()
	task.delay(0.055, function()
		if camera.Parent then TweenService:Create(camera, TweenInfo.new(0.10), { FieldOfView = base }):Play() end
	end)
end

local function onCombatEvent(payload)
	if type(payload) ~= "table" or type(payload.type) ~= "string" then return end
	if payload.type == "Stunned" and type(payload.duration) == "number" then
		stunnedUntil = math.max(stunnedUntil, os.clock() + payload.duration)
	elseif payload.type == "HitConfirmed" then
		fovKick(2.2)
	elseif payload.type == "PerfectBlock" then
		fovKick(1.4)
	elseif payload.type == "Parried" then
		fovKick(-1.8)
	end
end

local function configureTouchButtons()
	ContextActionService:SetTitle("PBCombatAttack", "HIT")
	ContextActionService:SetTitle("PBCombatLauncher", "UP")
	ContextActionService:SetTitle("PBCombatBlock", "BLOCK")
	ContextActionService:SetTitle("PBCombatDash", "DASH")
	ContextActionService:SetTitle("PBCombatLock", "LOCK")
	ContextActionService:SetPosition("PBCombatAttack", UDim2.new(1, -110, 1, -150))
	ContextActionService:SetPosition("PBCombatLauncher", UDim2.new(1, -210, 1, -210))
	ContextActionService:SetPosition("PBCombatBlock", UDim2.new(1, -110, 1, -260))
	ContextActionService:SetPosition("PBCombatDash", UDim2.new(1, -310, 1, -150))
	ContextActionService:SetPosition("PBCombatLock", UDim2.new(1, -310, 1, -260))
end

function CombatController.start()
	if started then return end
	started = true
	CombatEvent.OnClientEvent:Connect(onCombatEvent)

	ContextActionService:BindActionAtPriority("PBCombatAttack", attackAction, true, 2500, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindActionAtPriority("PBCombatLauncher", launcherAction, true, 2500, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
	ContextActionService:BindActionAtPriority("PBCombatBlock", blockAction, true, 2500, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
	ContextActionService:BindActionAtPriority("PBCombatDash", dashAction, true, 2500, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority("PBCombatLock", lockAction, true, 2500, Enum.UserInputType.MouseButton3, Enum.KeyCode.ButtonR3)
	ContextActionService:BindActionAtPriority("PBCombatCycle", cycleAction, false, 2500, Enum.KeyCode.Tab)
	configureTouchButtons()

	RunService.RenderStepped:Connect(function()
		refreshTarget()
		local _, humanoid = characterParts(player)
		if hardLock and currentTarget then
			if humanoid then humanoid.AutoRotate = false end
			faceTarget(currentTarget, false)
		elseif humanoid then
			humanoid.AutoRotate = true
		end
	end)

	print("[PocketBuddy] PvP CombatController started")
end

return CombatController
