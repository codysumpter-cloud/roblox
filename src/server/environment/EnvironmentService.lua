--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Terrain = workspace.Terrain
local Config = require(script.Parent.EnvironmentConfig)
local EnvironmentService = {}
local started = false

local function canonicalChild(className: string, name: string): Instance
	local found = Lighting:FindFirstChild(name)
	if found and found.ClassName == className then return found end
	if found then found:Destroy() end
	for _, child in Lighting:GetChildren() do
		if child.ClassName == className then
			child.Name = name
			return child
		end
	end
	local instance = Instance.new(className); instance.Name = name; instance.Parent = Lighting
	return instance
end

local function removeDuplicateEnvironmentObjects()
	local keep = {}
	for _, spec in { { "Sky", "PocketBuddySky" }, { "Atmosphere", "PocketBuddyAtmosphere" }, { "BloomEffect", "PocketBuddyBloom" }, { "SunRaysEffect", "PocketBuddySunRays" }, { "ColorCorrectionEffect", "PocketBuddyColor" } } do
		keep[canonicalChild(spec[1], spec[2])] = true
	end
	for _, child in Lighting:GetChildren() do
		if (child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("BloomEffect") or child:IsA("SunRaysEffect") or child:IsA("ColorCorrectionEffect")) and not keep[child] then child:Destroy() end
	end
end

local function stateFolder(): Folder
	local root = ReplicatedStorage:WaitForChild("PocketBuddy")
	local current = root:FindFirstChild("EnvironmentState")
	if current and current:IsA("Folder") then return current end
	if current then current:Destroy() end
	local folder = Instance.new("Folder"); folder.Name = "EnvironmentState"; folder.Parent = root
	return folder
end

local function timePalette(clockTime: number)
	if clockTime >= 6 and clockTime < 9 then return Color3.fromRGB(255, 205, 165), Color3.fromRGB(255, 166, 118), 1.85 end
	if clockTime >= 9 and clockTime < 17.5 then return Color3.fromRGB(255, 247, 230), Color3.fromRGB(220, 236, 255), 2.35 end
	if clockTime >= 17.5 and clockTime < 20 then return Color3.fromRGB(255, 188, 122), Color3.fromRGB(255, 132, 92), 1.9 end
	return Color3.fromRGB(75, 91, 145), Color3.fromRGB(30, 40, 78), 1.15
end

function EnvironmentService.start()
	if started then return end
	started = true
	removeDuplicateEnvironmentObjects()
	local state = stateFolder()
	local atmosphere = Lighting:FindFirstChild("PocketBuddyAtmosphere") :: Atmosphere
	local bloom = Lighting:FindFirstChild("PocketBuddyBloom") :: BloomEffect
	local sunRays = Lighting:FindFirstChild("PocketBuddySunRays") :: SunRaysEffect
	local color = Lighting:FindFirstChild("PocketBuddyColor") :: ColorCorrectionEffect
	local clouds = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Name = "PocketBuddyClouds"; clouds.Parent = Terrain
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.12, 38, 1
	sunRays.Intensity, sunRays.Spread = 0.07, 0.9
	color.Contrast, color.Saturation = 0.06, 0.08
	local elapsed, weatherElapsed, weatherIndex = 0, 0, 1
	local current = Config.weatherSequence[weatherIndex]
	local previousWeatherName = current.name
	local debugFolder = ServerStorage:FindFirstChild("PocketBuddyEnvironmentDebug") or Instance.new("Folder")
	debugFolder.Name = "PocketBuddyEnvironmentDebug"; debugFolder.Parent = ServerStorage
	local forceWeather = debugFolder:FindFirstChild("ForceWeather") or Instance.new("StringValue")
	forceWeather.Name = "ForceWeather"; forceWeather.Parent = debugFolder
	local forceClock = debugFolder:FindFirstChild("ForceClockTime") or Instance.new("NumberValue")
	forceClock.Name = "ForceClockTime"; forceClock.Value = -1; forceClock.Parent = debugFolder
	state:SetAttribute("Weather", current.name); state:SetAttribute("WeatherIntensity", 0)
	state:SetAttribute("TimeOwner", "PocketBuddy.EnvironmentService"); state:SetAttribute("WeatherOwner", "PocketBuddy.EnvironmentService")
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt; weatherElapsed += dt
		if weatherElapsed >= current.duration then
			weatherElapsed -= current.duration; previousWeatherName = current.name; weatherIndex = weatherIndex % #Config.weatherSequence + 1
			current = Config.weatherSequence[weatherIndex]; state:SetAttribute("Weather", current.name)
		end
		local forced = Config.weather[forceWeather.Value]
		local currentWeatherName = if forced then forceWeather.Value else current.name
		state:SetAttribute("Weather", currentWeatherName)
		local clockTime = if forceClock.Value >= 0 then forceClock.Value % 24 else (Config.startingClockTime + elapsed / Config.dayDurationSeconds * 24) % 24
		Lighting.ClockTime = clockTime; state:SetAttribute("ClockTime", clockTime)
		local weather = Config.weather[currentWeatherName]
		local transition = math.clamp(weatherElapsed / Config.transitionSeconds, 0, 1)
		local previous = if forced then weather else Config.weather[previousWeatherName]
		atmosphere.Density = math.lerp(previous.atmosphereDensity, weather.atmosphereDensity, transition)
		atmosphere.Haze = math.lerp(previous.haze, weather.haze, transition)
		clouds.Cover = math.lerp(previous.cloudCover, weather.cloudCover, transition)
		clouds.Density = math.lerp(previous.cloudDensity, weather.cloudDensity, transition)
		local top, bottom, timeBrightness = timePalette(clockTime)
		Lighting.ColorShift_Top, Lighting.ColorShift_Bottom = top, bottom
		Lighting.Brightness = math.min(timeBrightness, math.lerp(previous.brightness, weather.brightness, transition))
		local previousWet = if previousWeatherName == "Rain" or previousWeatherName == "Storm" then 1 else 0
		local currentWet = if currentWeatherName == "Rain" or currentWeatherName == "Storm" then 1 else 0
		state:SetAttribute("WeatherIntensity", if forced then currentWet else math.lerp(previousWet, currentWet, transition))
	end)
	print("[PocketBuddy] environment owner active; weather=Clear; time cycle enabled")
end
return EnvironmentService
