--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.PocketBuddy.Shared.core.combat.CombatConfig)
local ComboRules = require(ReplicatedStorage.PocketBuddy.Shared.core.combat.ComboRules)
local HitboxService = require(script.Parent.HitboxService)
local RemoteService = require(script.Parent.RemoteService)

local CombatService = {}

type PlayerCombatState = {
	comboIndex: number,
	lastAttackAt: number,
	actionLockedUntil: number,
	stunnedUntil: number,
	blocking: boolean,
	blockStartedAt: number,
	guard: number,
	lastGuardHitAt: number,
	dashReadyAt: number,
	launcherReadyAt: number,
	actionSerial: number,
	bufferedLightToken: number,
}

local states: {[Player]: PlayerCombatState} = {}
local started = false

local function newState(): PlayerCombatState
	return {
		comboIndex = 0,
		lastAttackAt = -math.huge,
		actionLockedUntil = 0,
		stunnedUntil = 0,
		blocking = false,
		blockStartedAt = -math.huge,
		guard = CombatConfig.GuardMax,
		lastGuardHitAt = -math.huge,
		dashReadyAt = 0,
		launcherReadyAt = 0,
		actionSerial = 0,
		bufferedLightToken = 0,
	}
end

local function getState(player: Player): PlayerCombatState
	local state = states[player]
	if not state then
		state = newState()
		states[player] = state
	end
	return state
end

local function getCharacterParts(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then return nil, nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return character, humanoid, nil end
	return character, humanoid, root
end

local function isAlive(player: Player): boolean
	local _, humanoid, root = getCharacterParts(player)
	return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function pushState(player: Player)
	local state = getState(player)
	RemoteService.CombatEvent:FireClient(player, {
		type = "State",
		blocking = state.blocking,
		guard = state.guard,
		stunnedUntil = state.stunnedUntil,
		comboIndex = state.comboIndex,
	})
end

local function invalidateBufferedLight(state: PlayerCombatState)
	state.bufferedLightToken += 1
end

local function stun(player: Player, duration: number)
	local state = getState(player)
	local now = os.clock()
	state.stunnedUntil = math.max(state.stunnedUntil, now + duration)
	state.actionLockedUntil = math.max(state.actionLockedUntil, state.stunnedUntil)
	state.blocking = false
	state.actionSerial += 1
	invalidateBufferedLight(state)
	RemoteService.CombatEvent:FireClient(player, { type = "Stunned", duration = duration })
	pushState(player)
end

local function canAct(player: Player): boolean
	if not isAlive(player) then return false end
	local state = getState(player)
	local now = os.clock()
	return not state.blocking and now >= state.stunnedUntil and ComboRules.canAct(now, state.actionLockedUntil)
end

local function isBlockingFront(target: Player, attackerRoot: BasePart): boolean
	local _, _, targetRoot = getCharacterParts(target)
	if not targetRoot then return false end
	local delta = attackerRoot.Position - targetRoot.Position
	if delta.Magnitude < 0.001 then return true end
	return targetRoot.CFrame.LookVector:Dot(delta.Unit) > 0.12
end

local function applyImpulse(attackerRoot: BasePart, targetRoot: BasePart, attack)
	local horizontal = targetRoot.Position - attackerRoot.Position
	horizontal = Vector3.new(horizontal.X, 0, horizontal.Z)
	if horizontal.Magnitude < 0.001 then
		horizontal = attackerRoot.CFrame.LookVector
	else
		horizontal = horizontal.Unit
	end
	local impulseVelocity = horizontal * (attack.Knockback or 0) + Vector3.new(0, attack.VerticalImpulse or 0, 0)
	if impulseVelocity.Magnitude > 0 then
		targetRoot:ApplyImpulse(impulseVelocity * targetRoot.AssemblyMass)
	end
end

local function applyHit(attacker: Player, target: Player, attack)
	local _, _, attackerRoot = getCharacterParts(attacker)
	local _, targetHumanoid, targetRoot = getCharacterParts(target)
	if not attackerRoot or not targetHumanoid or not targetRoot or targetHumanoid.Health <= 0 then return end

	local targetState = getState(target)
	local now = os.clock()
	if targetState.blocking and isBlockingFront(target, attackerRoot) then
		if now - targetState.blockStartedAt <= CombatConfig.PerfectBlockWindow then
			stun(attacker, 0.52)
			RemoteService.CombatEvent:FireClient(target, { type = "PerfectBlock", attacker = attacker.UserId })
			RemoteService.CombatEvent:FireClient(attacker, { type = "Parried", target = target.UserId })
			return
		end

		targetState.guard = math.max(0, targetState.guard - (attack.GuardDamage or attack.Damage))
		targetState.lastGuardHitAt = now
		if targetState.guard <= 0 then
			targetState.blocking = false
			stun(target, 0.85)
			RemoteService.CombatEvent:FireAllClients({ type = "GuardBreak", target = target.UserId, attacker = attacker.UserId })
		else
			RemoteService.CombatEvent:FireClient(target, { type = "Blocked", attacker = attacker.UserId, guard = targetState.guard })
			RemoteService.CombatEvent:FireClient(attacker, { type = "AttackBlocked", target = target.UserId })
			pushState(target)
		end
		return
	end

	targetHumanoid:TakeDamage(attack.Damage)
	applyImpulse(attackerRoot, targetRoot, attack)
	stun(target, attack.Stun or 0.2)
	if attack.Ragdoll then
		local targetCharacter = target.Character
		if targetCharacter then targetCharacter:SetAttribute("CombatRagdollUntil", now + attack.Ragdoll) end
	end

	RemoteService.CombatEvent:FireClient(attacker, {
		type = "HitConfirmed",
		target = target.UserId,
		damage = attack.Damage,
	})
	RemoteService.CombatEvent:FireClient(target, {
		type = "HitTaken",
		attacker = attacker.UserId,
		damage = attack.Damage,
		ragdoll = attack.Ragdoll,
	})
end

local function performLightAttack(player: Player)
	if not canAct(player) then return end
	local state = getState(player)
	invalidateBufferedLight(state)
	local now = os.clock()
	local combo = CombatConfig.LightCombo
	local index = ComboRules.nextIndex(state.comboIndex, now - state.lastAttackAt, #combo, CombatConfig.ComboResetSeconds)
	local attack = combo[index]
	state.comboIndex = index
	state.lastAttackAt = now
	state.actionLockedUntil = now + attack.Recovery
	state.actionSerial += 1
	local serial = state.actionSerial
	pushState(player)
	RemoteService.CombatEvent:FireAllClients({ type = "AttackStarted", attacker = player.UserId, move = "Light", comboIndex = index })

	task.delay(attack.Startup, function()
		local current = states[player]
		if not current or current.actionSerial ~= serial or not isAlive(player) or os.clock() < current.stunnedUntil then return end
		for _, target in HitboxService.findPlayerTargets(player, attack, CombatConfig.Targeting.MaxRange) do
			applyHit(player, target, attack)
		end
	end)
end

local function lightAttack(player: Player)
	if not isAlive(player) then return end
	local state = getState(player)
	local now = os.clock()
	if state.blocking or now < state.stunnedUntil then return end
	if now >= state.actionLockedUntil then
		performLightAttack(player)
		return
	end

	local remaining = state.actionLockedUntil - now
	if remaining > CombatConfig.InputBufferSeconds then return end
	invalidateBufferedLight(state)
	local token = state.bufferedLightToken
	task.delay(remaining, function()
		local current = states[player]
		if current and current.bufferedLightToken == token and not current.blocking and os.clock() >= current.stunnedUntil then
			performLightAttack(player)
		end
	end)
end

local function launcher(player: Player)
	if not canAct(player) then return end
	local state = getState(player)
	local now = os.clock()
	if now < state.launcherReadyAt then return end
	invalidateBufferedLight(state)
	state.launcherReadyAt = now + CombatConfig.LauncherCooldown
	state.actionLockedUntil = now + CombatConfig.Launcher.Recovery
	state.comboIndex = 0
	state.actionSerial += 1
	local serial = state.actionSerial
	RemoteService.CombatEvent:FireAllClients({ type = "AttackStarted", attacker = player.UserId, move = "Launcher" })

	task.delay(CombatConfig.Launcher.Startup, function()
		local current = states[player]
		if not current or current.actionSerial ~= serial or not isAlive(player) or os.clock() < current.stunnedUntil then return end
		for _, target in HitboxService.findPlayerTargets(player, CombatConfig.Launcher, CombatConfig.Targeting.MaxRange) do
			applyHit(player, target, CombatConfig.Launcher)
		end
	end)
end

local function dash(player: Player, payload)
	if not canAct(player) then return end
	local state = getState(player)
	local now = os.clock()
	if now < state.dashReadyAt then return end
	local _, _, root = getCharacterParts(player)
	if not root then return end

	local direction = payload.direction
	if typeof(direction) ~= "Vector3" then direction = root.CFrame.LookVector end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.1 then direction = root.CFrame.LookVector else direction = direction.Unit end

	invalidateBufferedLight(state)
	state.dashReadyAt = now + CombatConfig.DashCooldown
	state.actionLockedUntil = now + 0.12
	state.actionSerial += 1
	root:ApplyImpulse(direction * CombatConfig.DashImpulse * root.AssemblyMass)
	RemoteService.CombatEvent:FireAllClients({ type = "Dash", player = player.UserId })
end

local function setBlocking(player: Player, enabled: boolean)
	local state = getState(player)
	local now = os.clock()
	if enabled then
		if not isAlive(player) or now < state.stunnedUntil or now < state.actionLockedUntil then return end
		invalidateBufferedLight(state)
		state.blocking = true
		state.blockStartedAt = now
		state.comboIndex = 0
		state.actionSerial += 1
	else
		state.blocking = false
	end
	pushState(player)
end

local function onIntent(player: Player, payload)
	if type(payload) ~= "table" or type(payload.action) ~= "string" then return end
	if not RemoteService.rateLimit(player, "combat_packet", 1 / 60) then return end

	if payload.action == "light" then
		lightAttack(player)
	elseif payload.action == "launcher" then
		launcher(player)
	elseif payload.action == "dash" then
		dash(player, payload)
	elseif payload.action == "block_start" then
		setBlocking(player, true)
	elseif payload.action == "block_end" then
		setBlocking(player, false)
	end
end

local function bindPlayer(player: Player)
	states[player] = newState()
	player.CharacterAdded:Connect(function()
		states[player] = newState()
		task.defer(pushState, player)
	end)
	if player.Character then task.defer(pushState, player) end
end

function CombatService.start()
	if started then return end
	started = true
	RemoteService.CombatIntent.OnServerEvent:Connect(onIntent)
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do bindPlayer(player) end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for player, state in states do
			if player.Parent and state.guard < CombatConfig.GuardMax and now - state.lastGuardHitAt >= CombatConfig.GuardRegenDelay then
				local before = state.guard
				state.guard = math.min(CombatConfig.GuardMax, state.guard + CombatConfig.GuardRegenPerSecond * dt)
				if math.floor(before / 10) ~= math.floor(state.guard / 10) then pushState(player) end
			end
		end
	end)

	print("[PocketBuddy] PvP CombatService started")
end

return CombatService
