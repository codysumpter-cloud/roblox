--!strict
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.PocketBuddy.Shared.core.Config)
local NeedsRules = require(game.ReplicatedStorage.PocketBuddy.Shared.core.NeedsRules)
local SaveSchema = require(game.ReplicatedStorage.PocketBuddy.Shared.core.SaveSchema)

local PlayerProfileService = require(script.Parent.services.PlayerProfileService)
local PetService = require(script.Parent.services.PetService)
local CareService = require(script.Parent.services.CareService)
local EggService = require(script.Parent.services.EggService)
local PartyService = require(script.Parent.services.PartyService)
local NativeAnimalAnimationService = require(script.Parent.services.NativeAnimalAnimationService)
local RemoteService = require(script.Parent.services.RemoteService)
local DemoWorldBuilder = require(script.Parent.world.DemoWorldBuilder)
local WorldAssetService = require(script.Parent.world.WorldAssetService)
local EnvironmentService = require(script.Parent.environment.EnvironmentService)
local AmbientAnimalService = require(script.Parent.world.AmbientAnimalService)

task.spawn(WorldAssetService.build)
AmbientAnimalService.start()
NativeAnimalAnimationService.start()
EnvironmentService.start()
if Config.BuildDemoWorld then
	DemoWorldBuilder.build()
end

CareService.bind()
EggService.bind()
PartyService.bind()

RemoteService.ProfileRequest.OnServerEvent:Connect(function(player)
	if RemoteService.rateLimit(player, "profile_request", 1) then return end
	if PlayerProfileService.get(player) then
		PetService.pushProfile(player)
	end
end)

local function added(player: Player)
	PlayerProfileService.load(player)
	PetService.spawnActive(player)
	-- The client also requests a snapshot, but this delayed server push covers the
	-- case where that request arrives while profile loading is still yielding.
	task.delay(1, function()
		if player.Parent and PlayerProfileService.get(player) then
			PetService.pushProfile(player)
		end
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		-- A party round owns the pet runtime. Avatar respawns must not replace the
		-- physical party pet or return the player to hub-companion mode mid-round.
		if PartyService.isInParty(player) then
			PartyService.refreshAvatar(player)
		else
			PetService.refresh(player)
		end
	end)
end

local function removing(player: Player)
	PlayerProfileService.save(player)
	PetService.remove(player)
	PlayerProfileService.remove(player)
	RemoteService.clearPlayer(player)
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
