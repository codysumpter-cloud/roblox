--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VFXController = require(script.Parent.VFXController)
local EnvironmentController = require(script.Parent.EnvironmentController)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("PocketBuddyRemotes")
local ProfileUpdated = remotes:WaitForChild("ProfileUpdated") :: RemoteEvent
local ProfileRequest = remotes:WaitForChild("ProfileRequest") :: RemoteEvent
local Notify = remotes:WaitForChild("Notify") :: RemoteEvent
local Intent = remotes:WaitForChild("Intent") :: RemoteEvent
local RoundUpdated = remotes:WaitForChild("RoundUpdated") :: RemoteEvent

VFXController.start()
EnvironmentController.start()

local gui = Instance.new("ScreenGui")
gui.Name = "PocketBuddyHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0, 1)
card.Position = UDim2.new(0, 18, 1, -18)
card.Size = UDim2.fromOffset(330, 136)
card.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
card.BackgroundTransparency = 0.08
card.BorderSizePixel = 0
card.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = card

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 9)
title.Size = UDim2.new(1, -28, 0, 26)
title.Font = Enum.Font.GothamBold
title.Text = "BUDDY"
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(245, 247, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = card

local detail = Instance.new("TextLabel")
detail.BackgroundTransparency = 1
detail.Position = UDim2.fromOffset(14, 39)
detail.Size = UDim2.new(1, -28, 0, 80)
detail.Font = Enum.Font.GothamMedium
detail.Text = "Waiting for pet..."
detail.TextWrapped = true
detail.TextSize = 14
detail.TextColor3 = Color3.fromRGB(210, 217, 232)
detail.TextXAlignment = Enum.TextXAlignment.Left
detail.TextYAlignment = Enum.TextYAlignment.Top
detail.Parent = card

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 24)
toast.Size = UDim2.fromOffset(360, 40)
toast.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.BorderSizePixel = 0
toast.Font = Enum.Font.GothamBold
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.TextSize = 15
toast.Parent = gui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = toast

local roundLabel = Instance.new("TextLabel")
roundLabel.AnchorPoint = Vector2.new(0.5, 0)
roundLabel.Position = UDim2.new(0.5, 0, 0, 70)
roundLabel.Size = UDim2.fromOffset(420, 34)
roundLabel.BackgroundTransparency = 1
roundLabel.Font = Enum.Font.GothamBold
roundLabel.TextColor3 = Color3.fromRGB(255, 240, 174)
roundLabel.TextSize = 18
roundLabel.Visible = false
roundLabel.Parent = gui

local partyActive = false
local held = {}
local lastMoveSent = 0
local keyActions = {
	[Enum.KeyCode.Space] = "jump",
	[Enum.KeyCode.F] = "grab",
	[Enum.KeyCode.E] = "shove",
	[Enum.KeyCode.Q] = "throw",
	[Enum.KeyCode.R] = "flop",
	[Enum.KeyCode.T] = "get_up",
}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not partyActive then return end
	local action = keyActions[input.KeyCode]
	if action then Intent:FireServer({ action = action }) end
	if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.D then
		held[input.KeyCode] = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	held[input.KeyCode] = nil
end)

RunService.RenderStepped:Connect(function()
	if not partyActive then return end
	if os.clock() - lastMoveSent < (1 / 15) then return end
	lastMoveSent = os.clock()
	local vector = Vector3.zero
	if held[Enum.KeyCode.W] then vector += Vector3.new(0, 0, -1) end
	if held[Enum.KeyCode.S] then vector += Vector3.new(0, 0, 1) end
	if held[Enum.KeyCode.A] then vector += Vector3.new(-1, 0, 0) end
	if held[Enum.KeyCode.D] then vector += Vector3.new(1, 0, 0) end
	if vector.Magnitude > 1 then vector = vector.Unit end
	Intent:FireServer({ action = "move", vector = vector })
end)

RoundUpdated.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	local players = payload.players
	local included = false
	if type(players) == "table" then
		for _, userId in players do if userId == player.UserId then included = true break end end
	end
	partyActive = included and (payload.phase == "Playing" or payload.phase == "Countdown")
	if partyActive then
		task.defer(function()
			local model = workspace:FindFirstChild(player.Name .. "_PartyBuddy")
			local root = model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
			if root and root:IsA("BasePart") then
				workspace.CurrentCamera.CameraSubject = root
			end
		end)
	elseif payload.phase == "Idle" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then workspace.CurrentCamera.CameraSubject = humanoid end
	end
	roundLabel.Visible = included
	if included then
		local phase = tostring(payload.phase or "")
		local seconds = payload.secondsLeft and (" · " .. tostring(math.ceil(payload.secondsLeft)) .. "s") or ""
		roundLabel.Text = string.upper(phase) .. seconds .. "  |  WASD move · Space jump · F grab · E shove · Q throw · R flop · T get up"
	end
	if payload.phase == "Idle" then roundLabel.Visible = false end
end)

ProfileUpdated.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or type(payload.eggs) ~= "table" then return end
	local pet = payload.activePet
	if type(pet) ~= "table" then return end
	title.Text = string.upper(pet.name or "BUDDY")
	detail.Text = ("Food %d   Clean %d   Happy %d\nFriendship %d   Pets %d\nEggs: Backyard %d · Play %d · Party %d"):format(
		math.floor(pet.needs.food),
		math.floor(pet.needs.clean),
		math.floor(pet.needs.happy),
		math.floor(pet.friendship or 0),
		payload.petCount or 1,
		payload.eggs.Backyard or 0,
		payload.eggs.Play or 0,
		payload.eggs.Party or 0
	)
end)

Notify.OnClientEvent:Connect(function(message)
	toast.Text = tostring(message)
	TweenService:Create(toast, TweenInfo.new(0.12), {
		TextTransparency = 0,
		BackgroundTransparency = 0.12,
	}):Play()
	task.delay(1.5, function()
		TweenService:Create(toast, TweenInfo.new(0.25), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
	end)
end)

-- Request the current snapshot after listeners are installed so a fast profile load
-- cannot leave a newly-created HUD showing "Waiting for pet...".
ProfileRequest:FireServer()

print("[PocketBuddy] client scaffold started")
