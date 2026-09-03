--!strict
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.PocketBuddy.Shared.core.Config)
local NeedsRules = require(game.ReplicatedStorage.PocketBuddy.Shared.core.NeedsRules)
local SaveSchema = require(game.ReplicatedStorage.PocketBuddy.Shared.core.SaveSchema)

local PlayerProfileService = require(script.Parent.services.PlayerProfileService)
local PetService = require(script.Parent.services.PetService)
local CareService = require(script.Parent.services.CareService)
local EggService = require(script.Parent.services.EggService)
local DemoWorldBuilder = require(script.Parent.world.DemoWorldBuilder)

if Config.BuildDemoWorld then
	DemoWorldBuilder.build()
end

CareService.bind()
EggService.bind()

local function added(player: Player)
	PlayerProfileService.load(player)
	PetService.spawnActive(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		PetService.refresh(player)
	end)
end

local function removing(player: Player)
	PlayerProfileService.save(player)
	PetService.remove(player)
	PlayerProfileService.remove(player)
end

Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(removing)
for _, player in Players:GetPlayers() do task.spawn(added, player) end

task.spawn(function()
	while true do
		task.wait(Config.NeedTickSeconds)
		for _, player in Players:GetPlayers() do
			local profile = PlayerProfileService.get(player)
			local pet = profile and SaveSchema.activePet(profile)
			if pet then
				NeedsRules.decay(pet, Config.NeedDecayPerTick)
				PetService.pushProfile(player)
			end
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerProfileService.save(player)
	end
end)

print("[PocketBuddy] server scaffold started")
