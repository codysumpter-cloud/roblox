--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local EnvironmentController = {}

local function setEmitters(root: Instance, enabled: boolean, intensity: number)
	for _, item in root:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			local baseRate = item:GetAttribute("PocketBuddyBaseRate")
			if type(baseRate) ~= "number" then baseRate = item.Rate; item:SetAttribute("PocketBuddyBaseRate", baseRate) end
			item.Enabled = enabled; item.Rate = baseRate * intensity
		end
	end
end

function EnvironmentController.start()
	local pocketBuddy = ReplicatedStorage:WaitForChild("PocketBuddy")
	local state = pocketBuddy:WaitForChild("EnvironmentState")
	local assets = pocketBuddy:FindFirstChild("WeatherAssets")
	local template = assets and assets:FindFirstChild("RainParticles")
	local rain = template and template:Clone()
	if rain then rain.Name = "PocketBuddyLocalRain"; rain.Parent = workspace.CurrentCamera or workspace end
	local rainSound: Sound? = nil
	if rain or assets then
		local source = (assets and assets:FindFirstChild("RainSound")) or (rain and rain:FindFirstChild("RainSound", true))
		if source and source:IsA("Sound") then rainSound = source:Clone(); rainSound.Name = "PocketBuddyRain"; rainSound.Looped = true; rainSound.Volume = 0; rainSound.Parent = SoundService; rainSound:Play() end
	end
	local nextFlash = 0
	RunService.RenderStepped:Connect(function()
		local intensity = state:GetAttribute("WeatherIntensity"); if type(intensity) ~= "number" then intensity = 0 end
		if rain then
			local camera = workspace.CurrentCamera
			if camera then rain:PivotTo(CFrame.new(camera.CFrame.Position + Vector3.new(0, 12, 0))) end
			setEmitters(rain, intensity > 0.02, math.clamp(intensity, 0, 1))
		end
		if rainSound then rainSound.Volume = intensity * 0.45 end
		if state:GetAttribute("Weather") == "Storm" and os.clock() >= nextFlash then
			nextFlash = os.clock() + math.random(6, 13)
			local original = Lighting.ExposureCompensation; Lighting.ExposureCompensation = original + 1.25
			task.delay(0.12, function() Lighting.ExposureCompensation = original end)
		end
	end)
end
return EnvironmentController
