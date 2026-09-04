--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.PocketBuddy.Shared.core.Config)
local HatchRules = require(game.ReplicatedStorage.PocketBuddy.Shared.core.HatchRules)
local PlayerProfileService = require(script.Parent.PlayerProfileService)
local PetService = require(script.Parent.PetService)
local RemoteService = require(script.Parent.RemoteService)
local IdAdapter = require(script.Parent.Parent.adapters.IdAdapter)

local EggService = {}
local hatchNonce = {}
local lastAction = {}
local MAX_DISTANCE = 12

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then return instance.Position end
	if instance:IsA("Model") then return instance:GetPivot().Position end
	return nil
end

local function playerNear(player: Player, instance: Instance): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = positionOf(instance)
	return root ~= nil and root:IsA("BasePart") and target ~= nil and (root.Position - target).Magnitude <= MAX_DISTANCE
end

local function rateLimited(player: Player, action: string): boolean
	local key = tostring(player.UserId) .. ":" .. action
	local now = os.clock()
	if now - (lastAction[key] or -math.huge) < Config.InteractionCooldown then
		return true
	end
	lastAction[key] = now
	return false
end

local function awardWorldEgg(player: Player, pickup: Instance)
	if not playerNear(player, pickup) or rateLimited(player, "egg_pickup") then return end
	local eggId = pickup:GetAttribute("EggId")
	local flag = pickup:GetAttribute("WorldFlag")
	if type(eggId) ~= "string" or type(flag) ~= "string" then return end

	local profile = PlayerProfileService.get(player)
	if not profile or profile.worldFlags[flag] then return end

	profile.worldFlags[flag] = true
	profile.eggs[eggId] = (profile.eggs[eggId] or 0) + 1
	PetService.pushProfile(player)
	RemoteService.Notify:FireClient(player, ("Found a %s Egg!"):format(eggId))
	local target = positionOf(pickup)
	if target then RemoteService.VFX:FireAllClients({ kind = "egg", position = target }) end
end

local function hatch(player: Player, station: Instance)
	if not playerNear(player, station) or rateLimited(player, "hatch") then return end
	local profile = PlayerProfileService.get(player)
	if not profile or #profile.pets >= Config.MaxPets then return end

	local eggId = nil
	for _, candidate in { "Backyard", "Play", "Party" } do
		if (profile.eggs[candidate] or 0) > 0 then
			eggId = candidate
			break
		end
	end

	if not eggId then
		RemoteService.Notify:FireClient(player, "You need an egg first.")
		return
	end

	hatchNonce[player] = (hatchNonce[player] or 0) + 1
	local pet, err = HatchRules.hatch(
		profile,
		eggId,
		IdAdapter.seed(player.UserId, hatchNonce[player]),
		IdAdapter.newPetId()
	)
	if not pet then
		warn("[PocketBuddy] hatch rejected", err)
		return
	end

	profile.activePetId = pet.id
	PetService.refresh(player)
	RemoteService.Notify:FireClient(player, ("Hatched %s!"):format(pet.name))
	local target = positionOf(station)
	if target then RemoteService.VFX:FireAllClients({ kind = "hatch", position = target }) end
end

function EggService.bind()
	for _, pickup in CollectionService:GetTagged("PocketBuddyEggPickup") do
		local prompt = pickup:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player)
				awardWorldEgg(player, pickup)
			end)
		end
	end

	for _, station in CollectionService:GetTagged("PocketBuddyHatchStation") do
		local prompt = station:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player)
				hatch(player, station)
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local prefix = tostring(player.UserId) .. ":"
		for key in lastAction do
			if string.sub(key, 1, #prefix) == prefix then lastAction[key] = nil end
		end
		hatchNonce[player] = nil
	end)
end

return EggService
