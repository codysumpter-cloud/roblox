--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("PocketBuddyRemotes")
local ProfileUpdated = remotes:WaitForChild("ProfileUpdated") :: RemoteEvent
local Notify = remotes:WaitForChild("Notify") :: RemoteEvent

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

ProfileUpdated.OnClientEvent:Connect(function(payload)
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

print("[PocketBuddy] client scaffold started")
