--!strict
local RunService = game:GetService("RunService")

local RemoteService = require(script.Parent.RemoteService)
local EnvironmentService = require(script.Parent.Parent.environment.EnvironmentService)
local WorldEventService = require(script.Parent.WorldEventService)

local AdminService = {}
local started = false

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then return true end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		return ok and rank == 255
	end
	return false
end

local function snapshot(player: Player): {[string]: any}
	local environment = EnvironmentService.getState()
	return {
		authorized = isAdmin(player),
		weather = environment.weather,
		clockTime = environment.clockTime,
		forcedWeather = environment.forcedWeather,
		forcedClockTime = environment.forcedClockTime,
		availableWeather = EnvironmentService.availableWeather(),
		tacoRain = WorldEventService.get("TacoRain"),
	}
end

local function push(player: Player)
	RemoteService.AdminState:FireClient(player, snapshot(player))
end

local function handle(player: Player, payload: any)
	if not isAdmin(player) then return end
	if not RemoteService.rateLimit(player, "admin_command", 0.12) then return end
	if type(payload) ~= "table" or type(payload.command) ~= "string" then return end

	local command = string.lower(payload.command)
	if command == "weather" then
		local value = payload.value
		if type(value) ~= "string" or #value > 32 then return end
		if not EnvironmentService.setWeather(value) then return end
	elseif command == "time" then
		local value = tonumber(payload.value)
		if not value or value < -240 or value > 240 then return end
		if not EnvironmentService.setClockTime(value) then return end
	elseif command == "resume" or command == "auto" then
		EnvironmentService.resumeAutomatic()
	elseif command == "tacos" or command == "taco_rain" then
		local mode = string.lower(tostring(payload.value or "toggle"))
		if mode == "on" or mode == "true" or mode == "1" then
			WorldEventService.set("TacoRain", true)
		elseif mode == "off" or mode == "false" or mode == "0" then
			WorldEventService.set("TacoRain", false)
		elseif mode == "toggle" then
			WorldEventService.toggle("TacoRain")
		else
			return
		end
	else
		return
	end
	push(player)
end

function AdminService.start()
	if started then return end
	started = true
	RemoteService.AdminCommand.OnServerEvent:Connect(handle)
	RemoteService.AdminStateRequest.OnServerEvent:Connect(function(player)
		if not RemoteService.rateLimit(player, "admin_state", 0.5) then return end
		push(player)
	end)
end

function AdminService.playerAdded(player: Player)
	task.defer(push, player)
end

function AdminService.isAdmin(player: Player): boolean
	return isAdmin(player)
end

return AdminService
