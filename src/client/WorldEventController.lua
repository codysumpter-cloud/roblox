--!strict
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local WorldEventController = {}
local started = false

local function tacoPartFromTemplate(template: Instance?): BasePart?
	if not template then return nil end
	if template:IsA("BasePart") then return template end
	return template:FindFirstChildWhichIsA("BasePart", true)
end

local function fallbackTaco(): BasePart
	local part = Instance.new("Part")
	part.Name = "PocketBuddyTaco"
	part.Size = Vector3.new(1.4, 0.35, 0.75)
	part.Color = Color3.fromRGB(235, 185, 78)
	part.Material = Enum.Material.SmoothPlastic
	return part
end

local function spawnTaco(source: BasePart?, center: Vector3)
	local taco = if source then source:Clone() else fallbackTaco()
	for _, item in taco:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then item:Destroy() end
	end
	taco.Name = "PocketBuddyTacoRain"
	taco.Anchored = false
	taco.CanCollide = false
	taco.CanQuery = false
	taco.CanTouch = false
	taco.Massless = true
	taco.CFrame = CFrame.new(center + Vector3.new(math.random(-28, 28), math.random(25, 42), math.random(-28, 28)))
		* CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
	taco.Parent = workspace
	taco.AssemblyLinearVelocity = Vector3.new(math.random(-3, 3), -math.random(16, 24), math.random(-3, 3))
	taco.AssemblyAngularVelocity = Vector3.new(math.random(-5, 5), math.random(-5, 5), math.random(-5, 5))
	Debris:AddItem(taco, 6)
end

function WorldEventController.start()
	if started then return end
	started = true
	local root = ReplicatedStorage:WaitForChild("PocketBuddy")
	local state = root:WaitForChild("EnvironmentState")
	local assets = root:WaitForChild("EventAssets")
	local source = tacoPartFromTemplate(assets:FindFirstChild("RainingTacos"))
	local soundTemplate = assets:FindFirstChild("TacoSound")
	local sound: Sound? = nil
	if soundTemplate and soundTemplate:IsA("Sound") then
		sound = soundTemplate:Clone()
		sound.Name = "PocketBuddyTacoRainSound"
		sound.Looped = true
		sound.Volume = math.min(sound.Volume, 0.5)
		sound.Parent = SoundService
	end

	local accumulator = 0
	local sounding = false
	RunService.RenderStepped:Connect(function(dt)
		local enabled = state:GetAttribute("TacoRain") == true
		if sound then
			if enabled and not sounding then sound:Play(); sounding = true end
			if not enabled and sounding then sound:Stop(); sounding = false end
		end
		if not enabled then accumulator = 0; return end
		accumulator += dt
		if accumulator < 0.16 then return end
		accumulator = 0
		local camera = workspace.CurrentCamera
		if not camera then return end
		for _ = 1, 3 do spawnTaco(source, camera.CFrame.Position) end
	end)
end

return WorldEventController
