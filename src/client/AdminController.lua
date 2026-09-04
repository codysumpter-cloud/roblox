--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AdminController = {}
local started = false

local function makeFallback(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "PocketBuddyAdmin"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -18, 0, 18)
	frame.Size = UDim2.fromOffset(250, 330)
	frame.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = frame
	local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6); layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; layout.Parent = frame
	local padding = Instance.new("UIPadding"); padding.PaddingTop = UDim.new(0, 10); padding.PaddingBottom = UDim.new(0, 10); padding.Parent = frame
	local title = Instance.new("TextLabel")
	title.Name = "Title"; title.Size = UDim2.new(1, -16, 0, 30); title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold; title.Text = "POCKET BUDDY ADMIN"; title.TextSize = 15; title.TextColor3 = Color3.new(1, 1, 1); title.Parent = frame
	for _, name in { "Clear", "Cloudy", "Rain", "Storm", "Fog", "Snow", "Raining Tacos", "Day", "Night", "Resume Auto" } do
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.new(1, -20, 0, 24)
		button.BackgroundColor3 = Color3.fromRGB(45, 51, 67)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamMedium
		button.Text = name
		button.TextSize = 13
		button.TextColor3 = Color3.fromRGB(238, 242, 255)
		button.Parent = frame
		local buttonCorner = Instance.new("UICorner"); buttonCorner.CornerRadius = UDim.new(0, 7); buttonCorner.Parent = button
	end
	return gui
end

local function buttonLabel(button: GuiButton): string
	local text = ""
	if button:IsA("TextButton") then text = button.Text end
	return string.lower(button.Name .. " " .. text)
end

local function bindButton(button: GuiButton, commandRemote: RemoteEvent): boolean
	local label = buttonLabel(button)
	if string.find(label, "taco", 1, true) then
		button.Activated:Connect(function() commandRemote:FireServer({ command = "tacos", value = "toggle" }) end)
		return true
	end
	for _, weather in { "Clear", "Cloudy", "Rain", "Storm", "Fog", "Snow" } do
		if string.find(label, string.lower(weather), 1, true) then
			button.Activated:Connect(function() commandRemote:FireServer({ command = "weather", value = weather }) end)
			return true
		end
	end
	local times = {
		{ tokens = { "sunrise", "morning" }, value = 7.5 },
		{ tokens = { "day", "noon" }, value = 12 },
		{ tokens = { "sunset", "evening" }, value = 18.5 },
		{ tokens = { "night", "midnight" }, value = 0 },
	}
	for _, entry in times do
		for _, token in entry.tokens do
			if string.find(label, token, 1, true) then
				button.Activated:Connect(function() commandRemote:FireServer({ command = "time", value = entry.value }) end)
				return true
			end
		end
	end
	if string.find(label, "auto", 1, true) or string.find(label, "resume", 1, true) then
		button.Activated:Connect(function() commandRemote:FireServer({ command = "resume" }) end)
		return true
	end
	return false
end

function AdminController.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local root = ReplicatedStorage:WaitForChild("PocketBuddy")
	local remotes = ReplicatedStorage:WaitForChild("PocketBuddyRemotes")
	local commandRemote = remotes:WaitForChild("AdminCommand") :: RemoteEvent
	local stateRequest = remotes:WaitForChild("AdminStateRequest") :: RemoteEvent
	local stateRemote = remotes:WaitForChild("AdminState") :: RemoteEvent
	local adminAssets = root:WaitForChild("AdminAssets")
	local imported = adminAssets:FindFirstChild("AdminPanel")
	local gui: ScreenGui
	if imported and imported:IsA("ScreenGui") then
		gui = imported:Clone()
		gui.Name = "PocketBuddyAdminV5"
		for _, item in gui:GetDescendants() do
			if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then item:Destroy() end
		end
	else
		gui = makeFallback()
	end
	gui.Enabled = false
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local bound = 0
	for _, item in gui:GetDescendants() do
		if item:IsA("GuiButton") and bindButton(item, commandRemote) then bound += 1 end
	end
	gui:SetAttribute("PocketBuddyBoundAdminButtons", bound)

	local authorized = false
	stateRemote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then return end
		authorized = payload.authorized == true
		if not authorized then gui.Enabled = false end
		gui:SetAttribute("Weather", tostring(payload.weather or ""))
		gui:SetAttribute("ClockTime", tonumber(payload.clockTime) or 0)
		gui:SetAttribute("TacoRain", payload.tacoRain == true)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not authorized then return end
		if input.KeyCode == Enum.KeyCode.F8 then gui.Enabled = not gui.Enabled end
	end)
	stateRequest:FireServer()
end

return AdminController
