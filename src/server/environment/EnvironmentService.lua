--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Terrain = workspace.Terrain
local Config = require(script.Parent.EnvironmentConfig)

local EnvironmentService = {}
local started = false
local state: Folder? = nil
local forceWeather: StringValue? = nil
local forceClock: NumberValue? = nil

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
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

local function removeDuplicateEnvironmentObjects()
	local keep = {}
	for _, spec in {
		{ "Sky", "PocketBuddySky" },
		{ "Atmosphere", "PocketBuddyAtmosphere" },
		{ "BloomEffect", "PocketBuddyBloom" },
		{ "SunRaysEffect", "PocketBuddySunRays" },
		{ "ColorCorrectionEffect", "PocketBuddyColor" },
	} do
		keep[canonicalChild(spec[1], spec[2])] = true
	end
	for _, child in Lighting:GetChildren() do
		if (child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("BloomEffect") or child:IsA("SunRaysEffect") or child:IsA("ColorCorrectionEffect")) and not keep[child] then
			child:Destroy()
		end
	end

	local canonicalClouds: Clouds? = nil
	for _, child in Terrain:GetChildren() do
		if child:IsA("Clouds") then
			if not canonicalClouds then
				canonicalClouds = child
				canonicalClouds.Name = "PocketBuddyClouds"
			else
				child:Destroy()
			end
		end
	end
	if not canonicalClouds then
		canonicalClouds = Instance.new("Clouds")
		canonicalClouds.Name = "PocketBuddyClouds"
		canonicalClouds.Parent = Terrain
	end
end

local function stateFolder(): Folder
	local root = ReplicatedStorage:WaitForChild("PocketBuddy")
	local current = root:FindFirstChild("EnvironmentState")
	if current and current:IsA("Folder") then return current end
	if current then current:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "EnvironmentState"
	folder.Parent = root
	return folder
end

local function timePalette(clockTime: number)
	if clockTime >= 6 and clockTime < 9 then return Color3.fromRGB(255, 205, 165), Color3.fromRGB(255, 166, 118), 1.85 end
	if clockTime >= 9 and clockTime < 17.5 then return Color3.fromRGB(255, 247, 230), Color3.fromRGB(220, 236, 255), 2.35 end
	if clockTime >= 17.5 and clockTime < 20 then return Color3.fromRGB(255, 188, 122), Color3.fromRGB(255, 132, 92), 1.9 end
	return Color3.fromRGB(75, 91, 145), Color3.fromRGB(30, 40, 78), 1.15
end

function EnvironmentService.isWeather(name: string): boolean
	return Config.weather[name] ~= nil
end

function EnvironmentService.availableWeather(): {string}
	local names = {}
	for name in Config.weather do table.insert(names, name) end
	table.sort(names)
	return names
end

function EnvironmentService.setWeather(name: string): boolean
	if not EnvironmentService.isWeather(name) then return false end
	if not forceWeather then return false end
	forceWeather.Value = name
	return true
end

function EnvironmentService.clearWeatherOverride()
	if forceWeather then forceWeather.Value = "" end
end

function EnvironmentService.setClockTime(clockTime: number): boolean
	if not forceClock or clockTime ~= clockTime then return false end
	forceClock.Value = clockTime % 24
	return true
end

function EnvironmentService.clearClockOverride()
	if forceClock then forceClock.Value = -1 end
end

function EnvironmentService.resumeAutomatic()
	EnvironmentService.clearWeatherOverride()
	EnvironmentService.clearClockOverride()
end

function EnvironmentService.getState(): {[string]: any}
	return {
		weather = state and state:GetAttribute("Weather") or "Clear",
		clockTime = state and state:GetAttribute("ClockTime") or Config.startingClockTime,
		forcedWeather = forceWeather and forceWeather.Value or "",
		forcedClockTime = forceClock and forceClock.Value or -1,
	}
end

function EnvironmentService.start()
	if started then return end
	started = true
	removeDuplicateEnvironmentObjects()
	state = stateFolder()

	local atmosphere = Lighting:FindFirstChild("PocketBuddyAtmosphere") :: Atmosphere
	local bloom = Lighting:FindFirstChild("PocketBuddyBloom") :: BloomEffect
	local sunRays = Lighting:FindFirstChild("PocketBuddySunRays") :: SunRaysEffect
	local color = Lighting:FindFirstChild("PocketBuddyColor") :: ColorCorrectionEffect
	local clouds = Terrain:FindFirstChild("PocketBuddyClouds") :: Clouds
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.12, 38, 1
	sunRays.Intensity, sunRays.Spread = 0.07, 0.9
	color.Contrast, color.Saturation = 0.06, 0.08

	local debugFolder = ServerStorage:FindFirstChild("PocketBuddyEnvironmentDebug") or Instance.new("Folder")
	debugFolder.Name = "PocketBuddyEnvironmentDebug"
	debugFolder.Parent = ServerStorage
	forceWeather = debugFolder:FindFirstChild("ForceWeather") :: StringValue?
	if not forceWeather then
		forceWeather = Instance.new("StringValue")
		forceWeather.Name = "ForceWeather"
		forceWeather.Parent = debugFolder
	end
	forceClock = debugFolder:FindFirstChild("ForceClockTime") :: NumberValue?
	if not forceClock then
		forceClock = Instance.new("NumberValue")
		forceClock.Name = "ForceClockTime"
		forceClock.Value = -1
		forceClock.Parent = debugFolder
	end

	local elapsed, weatherElapsed, weatherIndex = 0, 0, 1
	local current = Config.weatherSequence[weatherIndex]
	local previousWeatherName = current.name
	state:SetAttribute("Weather", current.name)
	state:SetAttribute("WeatherIntensity", 0)
	state:SetAttribute("PrecipitationIntensity", 0)
	state:SetAttribute("TimeOwner", "PocketBuddy.EnvironmentService")
	state:SetAttribute("WeatherOwner", "PocketBuddy.EnvironmentService")

	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		weatherElapsed += dt
		if weatherElapsed >= current.duration then
			weatherElapsed -= current.duration
			previousWeatherName = current.name
			weatherIndex = weatherIndex % #Config.weatherSequence + 1
			current = Config.weatherSequence[weatherIndex]
		end

		local forcedName = forceWeather and forceWeather.Value or ""
		local forcedWeatherConfig = Config.weather[forcedName]
		local currentWeatherName = if forcedWeatherConfig then forcedName else current.name
		state:SetAttribute("Weather", currentWeatherName)

		local forcedClock = forceClock and forceClock.Value or -1
		local clockTime = if forcedClock >= 0 then forcedClock % 24 else (Config.startingClockTime + elapsed / Config.dayDurationSeconds * 24) % 24
		Lighting.ClockTime = clockTime
		state:SetAttribute("ClockTime", clockTime)

		local weather = Config.weather[currentWeatherName]
		local transition = if forcedWeatherConfig then 1 else math.clamp(weatherElapsed / Config.transitionSeconds, 0, 1)
		local previous = if forcedWeatherConfig then weather else Config.weather[previousWeatherName]
		atmosphere.Density = math.lerp(previous.atmosphereDensity, weather.atmosphereDensity, transition)
		atmosphere.Haze = math.lerp(previous.haze, weather.haze, transition)
		clouds.Cover = math.lerp(previous.cloudCover, weather.cloudCover, transition)
		clouds.Density = math.lerp(previous.cloudDensity, weather.cloudDensity, transition)

		local top, bottom, timeBrightness = timePalette(clockTime)
		Lighting.ColorShift_Top, Lighting.ColorShift_Bottom = top, bottom
		Lighting.Brightness = math.min(timeBrightness, math.lerp(previous.brightness, weather.brightness, transition))

		local previousPrecipitation = previous.precipitation or 0
		local currentPrecipitation = weather.precipitation or 0
		local precipitation = math.lerp(previousPrecipitation, currentPrecipitation, transition)
		state:SetAttribute("PrecipitationIntensity", precipitation)
		state:SetAttribute("WeatherIntensity", precipitation)
	end)
	print("[PocketBuddy] authoritative environment owner active; duplicate skies/weather loops suppressed")
end

return EnvironmentService
