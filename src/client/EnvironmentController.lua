--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local EnvironmentController = {}
local started = false

local function setEmitters(root: Instance, enabled: boolean, intensity: number)
	if root:IsA("ParticleEmitter") then
		local baseRate = root:GetAttribute("PocketBuddyBaseRate")
		if type(baseRate) ~= "number" then baseRate = root.Rate; root:SetAttribute("PocketBuddyBaseRate", baseRate) end
		root.Enabled = enabled
		root.Rate = baseRate * intensity
	end
	for _, item in root:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			local baseRate = item:GetAttribute("PocketBuddyBaseRate")
			if type(baseRate) ~= "number" then baseRate = item.Rate; item:SetAttribute("PocketBuddyBaseRate", baseRate) end
			item.Enabled = enabled
			item.Rate = baseRate * intensity
		end
	end
end

local function emitterAnchor(template: Instance): BasePart
	local anchor = Instance.new("Part")
	anchor.Name = "PocketBuddyLocalWeather"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	local attachment = Instance.new("Attachment")
	attachment.Name = "WeatherEmitterAttachment"
	attachment.Parent = anchor
	local function copyEmitter(item: Instance)
		if item:IsA("ParticleEmitter") then item:Clone().Parent = attachment end
	end
	copyEmitter(template)
	for _, item in template:GetDescendants() do copyEmitter(item) end
	return anchor
end

local function visualClone(template: Instance?): Instance?
	if not template then return nil end
	if template:IsA("BasePart") or template:IsA("Model") then
		local clone = template:Clone()
		for _, item in clone:GetDescendants() do
			if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then item:Destroy() end
			if item:IsA("BasePart") then
				item.Anchored = true; item.CanCollide = false; item.CanQuery = false; item.CanTouch = false
			end
		end
		if clone:IsA("BasePart") then clone.Anchored = true; clone.CanCollide = false; clone.CanQuery = false; clone.CanTouch = false end
		return clone
	end
	return emitterAnchor(template)
end

local function moveVisual(visual: Instance, position: Vector3)
	local cf = CFrame.new(position + Vector3.new(0, 12, 0))
	if visual:IsA("Model") then visual:PivotTo(cf)
	elseif visual:IsA("BasePart") then visual.CFrame = cf end
end

local function soundClone(assets: Folder, name: string): Sound?
	local source = assets:FindFirstChild(name)
	if not source or not source:IsA("Sound") then return nil end
	local sound = source:Clone()
	sound.Name = "PocketBuddy" .. name
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	return sound
end

function EnvironmentController.start()
	if started then return end
	started = true
	local pocketBuddy = ReplicatedStorage:WaitForChild("PocketBuddy")
	local state = pocketBuddy:WaitForChild("EnvironmentState")
	local assets = pocketBuddy:WaitForChild("WeatherAssets") :: Folder
	local rain = visualClone(assets:FindFirstChild("RainParticles"))
	local snow = visualClone(assets:FindFirstChild("SnowParticles"))
	local fog = visualClone(assets:FindFirstChild("FogVisual"))
	local lightning = visualClone(assets:FindFirstChild("LightningVisual"))
	for _, visual in { rain, snow, fog, lightning } do if visual then visual.Parent = workspace end end
	local rainSound = soundClone(assets, "RainSound")
	local snowSound = soundClone(assets, "SnowSound")
	local nextFlash = 0

	RunService.RenderStepped:Connect(function()
		local intensity = state:GetAttribute("PrecipitationIntensity")
		if type(intensity) ~= "number" then intensity = state:GetAttribute("WeatherIntensity") end
		if type(intensity) ~= "number" then intensity = 0 end
		intensity = math.clamp(intensity, 0, 1)
		local weather = tostring(state:GetAttribute("Weather") or "Clear")
		local camera = workspace.CurrentCamera
		if camera then
			for _, visual in { rain, snow, fog, lightning } do if visual then moveVisual(visual, camera.CFrame.Position) end end
		end
		if rain then setEmitters(rain, weather == "Rain" or weather == "Storm", intensity) end
		if snow then setEmitters(snow, weather == "Snow", intensity) end
		if fog then setEmitters(fog, weather == "Fog", if weather == "Fog" then 1 else 0) end
		if lightning then setEmitters(lightning, false, 0) end
		if rainSound then rainSound.Volume = (if weather == "Rain" or weather == "Storm" then intensity else 0) * 0.45 end
		if snowSound then snowSound.Volume = (if weather == "Snow" then intensity else 0) * 0.35 end
		if weather == "Storm" and os.clock() >= nextFlash then
			nextFlash = os.clock() + math.random(6, 13)
			if lightning then
				for _, item in lightning:GetDescendants() do if item:IsA("ParticleEmitter") then item:Emit(math.max(item:GetAttribute("BurstCount") or 1, 1)) end end
			end
			local original = Lighting.ExposureCompensation
			Lighting.ExposureCompensation = original + 1.25
			task.delay(0.12, function() Lighting.ExposureCompensation = original end)
		end
	end)
end

return EnvironmentController
