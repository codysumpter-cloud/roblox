--!strict
-- Safe, visual-only effects. No third-party scripts are copied or executed here.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VFXController = {}
local BUILTIN_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local MAX_DISTANCE = 350

type Style = {
	colors: { Color3 },
	count: number,
	lifetime: NumberRange,
	speed: NumberRange,
	size: NumberSequence,
	spread: Vector2,
}

local styles: { [string]: Style } = {
	feed = {
		colors = { Color3.fromRGB(255, 179, 71), Color3.fromRGB(255, 235, 154) },
		count = 18,
		lifetime = NumberRange.new(0.45, 0.8),
		speed = NumberRange.new(5, 9),
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.38), NumberSequenceKeypoint.new(1, 0) }),
		spread = Vector2.new(50, 50),
	},
	wash = {
		colors = { Color3.fromRGB(83, 221, 255), Color3.fromRGB(213, 250, 255) },
		count = 26,
		lifetime = NumberRange.new(0.5, 0.9),
		speed = NumberRange.new(7, 12),
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		spread = Vector2.new(70, 35),
	},
	friendship = {
		colors = { Color3.fromRGB(255, 118, 177), Color3.fromRGB(255, 213, 235) },
		count = 22,
		lifetime = NumberRange.new(0.65, 1.05),
		speed = NumberRange.new(3, 7),
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.7, 0.25), NumberSequenceKeypoint.new(1, 0) }),
		spread = Vector2.new(60, 25),
	},
	play = {
		colors = { Color3.fromRGB(166, 112, 255), Color3.fromRGB(90, 229, 255) },
		count = 24,
		lifetime = NumberRange.new(0.5, 0.9),
		speed = NumberRange.new(6, 11),
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.42), NumberSequenceKeypoint.new(1, 0) }),
		spread = Vector2.new(80, 55),
	},
	egg = {
		colors = { Color3.fromRGB(255, 223, 86), Color3.fromRGB(255, 255, 225) },
		count = 34,
		lifetime = NumberRange.new(0.65, 1.1),
		speed = NumberRange.new(7, 14),
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.58), NumberSequenceKeypoint.new(1, 0) }),
		spread = Vector2.new(110, 70),
	},
	hatch = {
		colors = { Color3.fromRGB(255, 240, 149), Color3.fromRGB(255, 118, 225), Color3.fromRGB(91, 224, 255) },
		count = 60,
		lifetime = NumberRange.new(0.9, 1.5),
		speed = NumberRange.new(10, 20),
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 0) }),
		spread = Vector2.new(180, 90),
	},
	winner = {
		colors = { Color3.fromRGB(255, 211, 64), Color3.fromRGB(255, 92, 148), Color3.fromRGB(91, 224, 255) },
		count = 90,
		lifetime = NumberRange.new(1.2, 2.2),
		speed = NumberRange.new(12, 24),
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 0) }),
		spread = Vector2.new(180, 90),
	},
}

local function colorSequence(colors: { Color3 }): ColorSequence
	local keypoints = {}
	local denominator = math.max(#colors - 1, 1)
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / denominator, color))
	end
	return ColorSequence.new(keypoints)
end

local function anchorAt(position: Vector3): Part
	local anchor = Instance.new("Part")
	anchor.Name = "PocketBuddyVFX"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position + Vector3.new(0, 1.5, 0)
	anchor.Parent = workspace
	Debris:AddItem(anchor, 3)
	return anchor
end

local function curatedBurst(kind: string, position: Vector3): boolean
	if kind ~= "friendship" and kind ~= "hatch" and kind ~= "winner" then return false end
	local pocketBuddy = ReplicatedStorage:FindFirstChild("PocketBuddy")
	local assets = pocketBuddy and pocketBuddy:FindFirstChild("FXAssets")
	local template = assets and assets:FindFirstChild("Healed")
	if not template or not template:IsA("BasePart") then return false end
	local effect = template:Clone()
	effect.Name = "PocketBuddyAnimeFX"
	effect.Anchored = true
	effect.CanCollide = false
	effect.CanQuery = false
	effect.CanTouch = false
	effect.Transparency = 1
	effect.Position = position + Vector3.new(0, 1.5, 0)
	effect.Parent = workspace
	for _, item in effect:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
			item:Destroy()
		elseif item:IsA("ParticleEmitter") then
			item.Enabled = false
			item:Emit(if kind == "winner" then 32 elseif kind == "hatch" then 24 else 12)
		end
	end
	Debris:AddItem(effect, 4)
	return true
end

local function burst(kind: string, position: Vector3)
	local style = styles[kind]
	if not style then return end
	curatedBurst(kind, position)
	local anchor = anchorAt(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = kind
	emitter.Texture = BUILTIN_SPARK
	emitter.Color = colorSequence(style.colors)
	emitter.LightEmission = 0.8
	emitter.Lifetime = style.lifetime
	emitter.Speed = style.speed
	emitter.Size = style.size
	emitter.SpreadAngle = style.spread
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-160, 160)
	emitter.Drag = 2
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(style.count)

	if kind == "hatch" or kind == "winner" then
		local light = Instance.new("PointLight")
		light.Color = style.colors[1]
		light.Brightness = if kind == "winner" then 5 else 4
		light.Range = 18
		light.Parent = anchor
		TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0, Range = 4 }):Play()
	end
end

local function countdown(position: Vector3, value: number?)
	local ring = Instance.new("Part")
	ring.Name = "PocketBuddyCountdownRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = if value == 1 then Color3.fromRGB(126, 255, 139) else Color3.fromRGB(255, 225, 100)
	ring.Transparency = 0.16
	ring.Size = Vector3.new(0.12, 3, 3)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.12, 18, 18),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.9)
end

function VFXController.start()
	local remote = ReplicatedStorage:WaitForChild("PocketBuddyRemotes"):WaitForChild("VFX") :: RemoteEvent
	remote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.kind) ~= "string" or typeof(payload.position) ~= "Vector3" then return end
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - payload.position).Magnitude > MAX_DISTANCE then return end
		if payload.kind == "countdown" then
			countdown(payload.position, if type(payload.value) == "number" then payload.value else nil)
		else
			burst(payload.kind, payload.position)
		end
	end)
end

return VFXController
