--!strict
local CollectionService = game:GetService("CollectionService")
local Config = require(game.ReplicatedStorage.PocketBuddy.Shared.core.Config)
local NeedsRules = require(game.ReplicatedStorage.PocketBuddy.Shared.core.NeedsRules)
local SaveSchema = require(game.ReplicatedStorage.PocketBuddy.Shared.core.SaveSchema)
local PlayerProfileService = require(script.Parent.PlayerProfileService)
local PetService = require(script.Parent.PetService)
local RemoteService = require(script.Parent.RemoteService)

local CareService = {}
local lastUse = {}
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

local function use(player: Player, station: Instance)
	if not playerNear(player, station) then return end
	local action = station:GetAttribute("CareAction")
	if type(action) ~= "string" then return end

	local key = tostring(player.UserId) .. ":" .. action
	local now = os.clock()
	if now - (lastUse[key] or -math.huge) < Config.InteractionCooldown then return end
	lastUse[key] = now

	local profile = PlayerProfileService.get(player)
	local pet = profile and SaveSchema.activePet(profile)
	if not pet then return end

	if NeedsRules.apply(pet, action) then
		PetService.pushProfile(player)
		RemoteService.Notify:FireClient(player, ("Buddy enjoyed %s!"):format(action))
	end
end

function CareService.bind()
	for _, station in CollectionService:GetTagged("PocketBuddyCareStation") do
		local prompt = station:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player)
				use(player, station)
			end)
		end
	end
end

return CareService
