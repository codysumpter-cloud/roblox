--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.PocketBuddy.Shared.core.Config)
local PartyModes = require(game.ReplicatedStorage.PocketBuddy.Shared.core.PartyModeDefinitions)
local RoundRules = require(game.ReplicatedStorage.PocketBuddy.Shared.core.RoundRules)
local SaveSchema = require(game.ReplicatedStorage.PocketBuddy.Shared.core.SaveSchema)
local AvatarAdapter = require(script.Parent.Parent.adapters.AvatarAdapter)
local PlayerProfileService = require(script.Parent.PlayerProfileService)
local PetService = require(script.Parent.PetService)
local RemoteService = require(script.Parent.RemoteService)

local PartyService = {}
local mode = PartyModes.KingOfTheCouch
local queue = {}
local queueSet = {}
local state = RoundRules.newState()
local inputs = {}
local grabbed = {}
local carriedBy = {}
local scheduled = false
local roundToken = 0
local lastIntent = {}
local startedAt = 0
local assemblingRound = false
local COUCH_CENTER = Vector3.new(0, 4.8, -28)
local roundCouchCenter = COUCH_CENTER
local COUCH_HALF_X = 9.5
local COUCH_HALF_Z = 4.0

local function findCouchCenter(): Vector3
	for _, instance in CollectionService:GetTagged("PocketBuddyPartyQueue") do
		if instance:IsA("BasePart") then
			return instance.Position + Vector3.new(0, instance.Size.Y / 2 + 1.3, 0)
		end
	end
	return COUCH_CENTER
end

local function isGrounded(root: BasePart): boolean
	return math.abs(root.Position.Y - roundCouchCenter.Y) <= 1.0
end

local function notify(player: Player, message: string)
	RemoteService.Notify:FireClient(player, message)
end

local function roundVFX(kind: string, position: Vector3, value: number?)
	for _, userId in state.players do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			RemoteService.VFX:FireClient(player, { kind = kind, position = position, value = value })
		end
	end
end

local function publish(secondsLeft: number?)
	local players = {}
	for _, userId in state.players do table.insert(players, userId) end
	RemoteService.RoundUpdated:FireAllClients({
		mode = mode.id,
		phase = state.phase,
		players = players,
		eliminated = state.eliminated,
		winnerUserId = state.winnerUserId,
		secondsLeft = secondsLeft,
	})
end

local function inRound(player: Player): boolean
	if state.phase == RoundRules.Phase.Idle then return false end
	for _, userId in state.players do
		if userId == player.UserId then return true end
	end
	return false
end

-- Exposed for lifecycle coordination in main.server.lua. Character respawns
-- during a round must not replace the server-owned party pet with a hub pet.
PartyService.isInParty = inRound

local function removeFromQueue(player: Player)
	if not queueSet[player.UserId] then return end
	queueSet[player.UserId] = nil
	for index, queued in queue do
		if queued == player then table.remove(queue, index) break end
	end
end

local function cancelRound(token: number, message: string)
	if token ~= roundToken then return end
	assemblingRound = false
	for _, userId in state.players do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			if PetService.isInParty(player) then
				AvatarAdapter.exitParty(player)
				PetService.spawnActive(player)
			end
			notify(player, message)
		end
	end
	state = RoundRules.newState()
	inputs = {}
	grabbed = {}
	carriedBy = {}
	publish()
end

local function finishRound(token: number)
	if token ~= roundToken or state.phase == RoundRules.Phase.Results then return end
	state.phase = RoundRules.Phase.Results
	local remaining = RoundRules.remaining(state)
	if #remaining == 1 then state.winnerUserId = remaining[1] end
	local winner = state.winnerUserId and Players:GetPlayerByUserId(state.winnerUserId)
	local winnerModel = winner and PetService.runtimeModel(winner)
	local winnerRoot = winnerModel and winnerModel.PrimaryPart
	if winnerRoot and winnerRoot:IsA("BasePart") then
		roundVFX("winner", winnerRoot.Position)
	else
		roundVFX("winner", roundCouchCenter)
	end
	local rewarded = false
	for _, userId in state.players do
		local player = Players:GetPlayerByUserId(userId)
		local profile = player and PlayerProfileService.get(player)
		if profile then
			profile.stats.partyGamesPlayed = (profile.stats.partyGamesPlayed or 0) + 1
			if userId == state.winnerUserId then
				profile.stats.partyWins = (profile.stats.partyWins or 0) + 1
				if not rewarded then
					profile.eggs.Party = (profile.eggs.Party or 0) + 1
					rewarded = true
					notify(player, "You won! Party Egg earned.")
				end
			end
			PetService.pushProfile(player)
		end
	end
	publish( mode.resultsSeconds )
	for _, userId in state.players do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			notify(player, winner and ("%s wins King of the Couch!"):format(winner.Name) or "Nobody stayed on the couch!")
		end
	end
	task.delay(mode.resultsSeconds, function()
		if token ~= roundToken then return end
		for _, userId in state.players do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				AvatarAdapter.exitParty(player)
				PetService.spawnActive(player)
			end
		end
		state = RoundRules.newState()
		inputs = {}
		grabbed = {}
		carriedBy = {}
		publish()
	end)
end

local function eliminate(userId: number)
	if state.eliminated[userId] then return end
	state.eliminated[userId] = true
	local player = Players:GetPlayerByUserId(userId)
	if player then
		local carrier = carriedBy[player]
		if carrier then
			grabbed[carrier] = nil
			local carrierModel = PetService.runtimeModel(carrier)
			local weld = carrierModel and carrierModel.PrimaryPart and carrierModel.PrimaryPart:FindFirstChild("PocketBuddyCarryWeld")
			if weld then weld:Destroy() end
		end
		local target = grabbed[player]
		if target then
			carriedBy[target] = nil
			local carrierModel = PetService.runtimeModel(player)
			local weld = carrierModel and carrierModel.PrimaryPart and carrierModel.PrimaryPart:FindFirstChild("PocketBuddyCarryWeld")
			if weld then weld:Destroy() end
		end
		carriedBy[player] = nil
		grabbed[player] = nil
		local model = PetService.runtimeModel(player)
		if model then model:SetAttribute("Eliminated", true) end
		notify(player, "Flop! You are out this round.")
	end
	if state.phase == RoundRules.Phase.Playing and not assemblingRound and #RoundRules.remaining(state) <= 1 then
		finishRound(roundToken)
	end
end

local function nearestTarget(player: Player, radius: number): (Player?, BasePart?)
	local model = PetService.runtimeModel(player)
	local root = model and model.PrimaryPart
	if not root or not root:IsA("BasePart") then return nil, nil end
	local bestPlayer, bestRoot, bestDistance
	for _, userId in state.players do
		if userId ~= player.UserId and not state.eliminated[userId] then
			local candidate = Players:GetPlayerByUserId(userId)
			local candidateModel = candidate and PetService.runtimeModel(candidate)
			local candidateRoot = candidateModel and candidateModel.PrimaryPart
			if candidate and candidateRoot and candidateRoot:IsA("BasePart") then
				local distance = (candidateRoot.Position - root.Position).Magnitude
				if distance <= radius and (bestDistance == nil or distance < bestDistance) then
					bestPlayer, bestRoot, bestDistance = candidate, candidateRoot, distance
				end
			end
		end
	end
	return bestPlayer, bestRoot
end

local function processIntent(player: Player, payload)
	if not inRound(player) or state.phase ~= RoundRules.Phase.Playing then return end
	if type(payload) ~= "table" or type(payload.action) ~= "string" then return end
	local action = payload.action
	local bucket = action == "move" and "party_move" or "party_action"
	if not RemoteService.rateLimit(player, bucket, action == "move" and (1 / 15) or 0.12) then return end
	if action == "move" then
		local vector = payload.vector
		if typeof(vector) ~= "Vector3" or vector.Magnitude > 1.01 then return end
		if vector.X ~= vector.X or vector.Y ~= vector.Y or vector.Z ~= vector.Z then return end
		inputs[player] = Vector3.new(math.clamp(vector.X, -1, 1), 0, math.clamp(vector.Z, -1, 1))
	elseif action == "jump" then
		lastIntent[player] = "jump"
	elseif action == "grab" then
		if grabbed[player] then return end
		local target = nearestTarget(player, 4.5)
		if target and not carriedBy[target] then
			local carrierModel = PetService.runtimeModel(player)
			local targetModel = PetService.runtimeModel(target)
			local carrierRoot = carrierModel and carrierModel.PrimaryPart
			local targetRoot = targetModel and targetModel.PrimaryPart
			if carrierRoot and carrierRoot:IsA("BasePart") and targetRoot and targetRoot:IsA("BasePart") then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "PocketBuddyCarryWeld"
				weld.Part0 = carrierRoot
				weld.Part1 = targetRoot
				weld.Parent = carrierRoot
				targetRoot.CFrame = carrierRoot.CFrame * CFrame.new(0, 1.8, -1.4)
				grabbed[player] = target
				carriedBy[target] = player
			end
		end
	elseif action == "throw" then
		local target = grabbed[player]
		grabbed[player] = nil
		if target then carriedBy[target] = nil end
		local targetModel = target and PetService.runtimeModel(target)
		local targetRoot = targetModel and targetModel.PrimaryPart
		local carrierModel = PetService.runtimeModel(player)
		local carrierRoot = carrierModel and carrierModel.PrimaryPart
		if targetRoot and targetRoot:IsA("BasePart") and carrierRoot and carrierRoot:IsA("BasePart") then
			local carryWeld = carrierRoot:FindFirstChild("PocketBuddyCarryWeld")
			if carryWeld then carryWeld:Destroy() end
			local direction = carrierRoot.CFrame.LookVector
			targetRoot:ApplyImpulse((direction * 65 + Vector3.new(0, 28, 0)) * targetRoot.AssemblyMass)
		end
	elseif action == "shove" then
		local target, targetRoot = nearestTarget(player, 4.5)
		local carrierModel = PetService.runtimeModel(player)
		local carrierRoot = carrierModel and carrierModel.PrimaryPart
		if target and targetRoot and carrierRoot and carrierRoot:IsA("BasePart") then
			local direction = (targetRoot.Position - carrierRoot.Position)
			if direction.Magnitude > 0 then targetRoot:ApplyImpulse((direction.Unit * 38 + Vector3.new(0, 8, 0)) * targetRoot.AssemblyMass) end
		end
	elseif action == "flop" then
		local model = PetService.runtimeModel(player)
		if model then
			model:SetAttribute("Flopped", true)
			local pivot = model:GetPivot()
			model:PivotTo(pivot * CFrame.Angles(math.rad(72), 0, math.rad(-12)))
			local root = model.PrimaryPart
			if root then root.AssemblyAngularVelocity = Vector3.new(0, 0, 3) end
			task.delay(0.9, function() if model.Parent then model:SetAttribute("Flopped", false) end end)
		end
	elseif action == "get_up" then
		local model = PetService.runtimeModel(player)
		if model then
			local pivot = model:GetPivot()
			local look = pivot.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude < 0.1 then flatLook = Vector3.new(0, 0, -1) end
			model:PivotTo(CFrame.lookAt(pivot.Position, pivot.Position + flatLook.Unit))
			local root = model.PrimaryPart
			if root then root.AssemblyAngularVelocity = Vector3.zero end
			model:SetAttribute("Flopped", false)
		end
	end
end

local function startRound()
	if #queue < mode.minPlayers or state.phase ~= RoundRules.Phase.Idle then return end
	roundToken += 1
	local token = roundToken
	state = RoundRules.newState()
	for index = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[index]
		table.insert(state.players, player.UserId)
	end
	queue = {}
	queueSet = {}
	state.phase = RoundRules.Phase.Countdown
	for seconds = mode.countdownSeconds, 1, -1 do
		if token ~= roundToken or state.phase ~= RoundRules.Phase.Countdown then return end
		publish(seconds)
		roundVFX("countdown", findCouchCenter(), seconds)
		task.wait(1)
	end
	if token ~= roundToken then return end
	if #RoundRules.remaining(state) < mode.minPlayers then
		cancelRound(token, "Couch round cancelled: not enough players remained.")
		return
	end
	state.phase = RoundRules.Phase.Playing
	startedAt = os.clock()
	roundCouchCenter = findCouchCenter()
	local slot = 0
	assemblingRound = true
	for _, userId in state.players do
		local player = Players:GetPlayerByUserId(userId)
		if player and PlayerProfileService.get(player) and AvatarAdapter.enterParty(player) then
			local nextSlot = slot + 1
			local petModel = PetService.enterParty(
				player,
				roundCouchCenter + Vector3.new((nextSlot - 1) * 2 - 4, 0, 0)
			)
			if petModel then
				slot = nextSlot
			else
				AvatarAdapter.exitParty(player)
				eliminate(userId)
			end
		else
			eliminate(userId)
		end
	end
	assemblingRound = false
	if #RoundRules.remaining(state) < mode.minPlayers then
		cancelRound(token, "Couch round cancelled: not enough players could enter.")
		return
	end
	publish(mode.roundSeconds)
end

function PartyService.refreshAvatar(player: Player)
	if inRound(player) then AvatarAdapter.enterParty(player) end
end

local function joinQueue(player: Player)
	if state.phase ~= RoundRules.Phase.Idle or inRound(player) then return end
	if not PlayerProfileService.get(player) then return end
	if not RemoteService.rateLimit(player, "queue", Config.InteractionCooldown) then return end
	if queueSet[player.UserId] then
		removeFromQueue(player)
		notify(player, "Left the couch queue.")
		return
	end
	if #queue >= mode.maxPlayers then notify(player, "The couch queue is full.") return end
	queueSet[player.UserId] = true
	table.insert(queue, player)
	notify(player, ("Couch queue: %d/%d"):format(#queue, mode.maxPlayers))
	if #queue >= mode.minPlayers and not scheduled then
		scheduled = true
		task.delay(2, function()
			scheduled = false
			startRound()
		end)
	end
end

function PartyService.bind()
	for _, queuePart in CollectionService:GetTagged("PocketBuddyPartyQueue") do
		local prompt = queuePart:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then prompt.Triggered:Connect(joinQueue) end
	end
	RemoteService.Intent.OnServerEvent:Connect(processIntent)
	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		if inRound(player) then eliminate(player.UserId) end
		inputs[player] = nil
		grabbed[player] = nil
		carriedBy[player] = nil
		lastIntent[player] = nil
		AvatarAdapter.clear(player)
	end)
end

RunService.Heartbeat:Connect(function()
	if state.phase ~= RoundRules.Phase.Playing then return end
	if os.clock() - startedAt >= mode.roundSeconds then finishRound(roundToken) return end
	for _, userId in state.players do
		if not state.eliminated[userId] then
			local player = Players:GetPlayerByUserId(userId)
			local model = player and PetService.runtimeModel(player)
			local root = model and model.PrimaryPart
			if not player or not root or not root:IsA("BasePart")
				or root.Position.Y < roundCouchCenter.Y - 3.8
				or math.abs(root.Position.X - roundCouchCenter.X) > COUCH_HALF_X
				or math.abs(root.Position.Z - roundCouchCenter.Z) > COUCH_HALF_Z then
				eliminate(userId)
			elseif model:GetAttribute("Flopped") ~= true then
				local input = inputs[player] or Vector3.zero
				local traits = SaveSchema.activePet(PlayerProfileService.get(player)).traits
				local speed = 14 * (traits.speed or 1)
				local velocity = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(input.X * speed, velocity.Y, input.Z * speed)
				if lastIntent[player] == "jump" and velocity.Y <= 1 and isGrounded(root) then
					root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 32 * (traits.jump or 1), root.AssemblyLinearVelocity.Z)
				end
				lastIntent[player] = nil
			end
		end
	end
end)

return PartyService
