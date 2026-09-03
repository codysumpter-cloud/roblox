--!strict
local RunService = game:GetService("RunService")
local SaveSchema = require(game.ReplicatedStorage.PocketBuddy.Shared.core.SaveSchema)
local PetRuntimeAdapter = require(script.Parent.Parent.adapters.PetRuntimeAdapter)
local PetAnimationAdapter = require(script.Parent.Parent.adapters.PetAnimationAdapter)
local PlayerProfileService = require(script.Parent.PlayerProfileService)
local RemoteService = require(script.Parent.RemoteService)

local PetService = {}
local runtime = {}
local partyMode = {}
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

	if runtime[player] then
		PetAnimationAdapter.clear(runtime[player])
		runtime[player]:Destroy()
	end
	local model = select(1, PetRuntimeAdapter.build(pet))
	PetRuntimeAdapter.prepare(model)
	model.Name = player.Name .. "_Buddy"
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = folder
	runtime[player] = model
	partyMode[player] = nil
	PetAnimationAdapter.setState(model, "idle")
	snapshot(player)
end

function PetService.enterParty(player: Player, position: Vector3)
	local profile = PlayerProfileService.get(player)
	local pet = profile and SaveSchema.activePet(profile)
	if not pet then return nil end
	if runtime[player] then
		PetAnimationAdapter.clear(runtime[player])
		runtime[player]:Destroy()
	end
	local model = select(1, PetRuntimeAdapter.build(pet))
	model.Name = player.Name .. "_PartyBuddy"
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PartyPet", true)
	model.Parent = folder
	model:PivotTo(CFrame.new(position))
	PetRuntimeAdapter.setPhysics(model, true)
	runtime[player] = model
	partyMode[player] = true
	PetAnimationAdapter.setState(model, "idle")
	return model
end

function PetService.isInParty(player: Player): boolean
	return partyMode[player] == true
end

function PetService.runtimeModel(player: Player): Model?
	return runtime[player]
end

function PetService.refresh(player: Player)
	PetService.spawnActive(player)
end

function PetService.pushProfile(player: Player)
	snapshot(player)
end

function PetService.remove(player: Player)
	if runtime[player] then
		PetAnimationAdapter.clear(runtime[player])
		runtime[player]:Destroy()
	end
	runtime[player] = nil
	partyMode[player] = nil
end

RunService.Heartbeat:Connect(function(dt)
	for player, model in runtime do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not partyMode[player] and rootPart and rootPart:IsA("BasePart") and model.Parent then
			local offset = rootPart.CFrame:VectorToWorldSpace(Vector3.new(3, -1.5, 2.4))
			local desiredPosition = rootPart.Position + offset
			local current = model:GetPivot()
			local distance = (current.Position - desiredPosition).Magnitude
			local facing = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z)
			if facing.Magnitude < 0.5 then
				local look = rootPart.CFrame.LookVector
				facing = Vector3.new(look.X, 0, look.Z)
			end
			local desired = CFrame.lookAt(desiredPosition, desiredPosition + facing)
			if distance > 80 then
				model:PivotTo(desired)
			else
				model:PivotTo(current:Lerp(desired, math.clamp(dt * 7, 0, 1)))
			end
			local speed = distance > 80 and 0 or distance / math.max(dt, 1 / 60)
			PetAnimationAdapter.setState(model, PetAnimationAdapter.stateForSpeed(speed, true), math.clamp(speed / 8, 0.8, 1.5))
		end
	end
end)

return PetService
