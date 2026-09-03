--!strict
local RunService = game:GetService("RunService")
local SaveSchema = require(game.ReplicatedStorage.PocketBuddy.Shared.core.SaveSchema)
local PetRuntimeAdapter = require(script.Parent.Parent.adapters.PetRuntimeAdapter)
local PlayerProfileService = require(script.Parent.PlayerProfileService)
local RemoteService = require(script.Parent.RemoteService)

local PetService = {}
local runtime = {}
local folder = workspace:FindFirstChild("PocketBuddies") or Instance.new("Folder")
folder.Name = "PocketBuddies"
folder.Parent = workspace

local function snapshot(player: Player)
	local profile = PlayerProfileService.get(player)
	if not profile then return end
	local pet = SaveSchema.activePet(profile)
	RemoteService.ProfileUpdated:FireClient(player, {
		activePet = pet,
		eggs = profile.eggs,
		petCount = #profile.pets,
	})
end

function PetService.spawnActive(player: Player)
	local profile = PlayerProfileService.get(player)
	local pet = profile and SaveSchema.activePet(profile)
	if not pet then return end

	if runtime[player] then runtime[player]:Destroy() end
	local model = PetRuntimeAdapter.buildPlaceholder(pet)
	PetRuntimeAdapter.prepare(model)
	model.Name = player.Name .. "_Buddy"
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = folder
	runtime[player] = model
	snapshot(player)
end

function PetService.refresh(player: Player)
	PetService.spawnActive(player)
end

function PetService.pushProfile(player: Player)
	snapshot(player)
end

function PetService.remove(player: Player)
	if runtime[player] then runtime[player]:Destroy() end
	runtime[player] = nil
end

RunService.Heartbeat:Connect(function(dt)
	for player, model in runtime do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") and model.Parent then
			local desired = rootPart.CFrame * CFrame.new(3, -1.5, 2.4)
			model:PivotTo(model:GetPivot():Lerp(desired, math.clamp(dt * 7, 0, 1)))
		end
	end
end)

return PetService
