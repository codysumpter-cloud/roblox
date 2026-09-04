--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contract = require(ReplicatedStorage.PocketBuddy.Shared.avatar.HumanoidRigContract)

local AdvancedAvatarAdapter = {}

local REQUIRED_R15 = {
	"Root", "Waist", "Neck",
	"LeftShoulder", "LeftElbow", "LeftWrist",
	"RightShoulder", "RightElbow", "RightWrist",
	"LeftHip", "LeftKnee", "LeftAnkle",
	"RightHip", "RightKnee", "RightAnkle",
}

local function isJoint(instance: Instance): boolean
	return instance:IsA("Bone") or instance:IsA("Motor6D") or instance:IsA("AnimationConstraint")
end

local function indexJoints(model: Model): {[string]: Instance}
	local out = {}
	for _, item in model:GetDescendants() do
		if isJoint(item) then out[string.lower(item.Name)] = item end
	end
	return out
end

local function findAlias(index: {[string]: Instance}, aliases: {string}): Instance?
	for _, name in aliases do
		local found = index[string.lower(name)]
		if found then return found end
	end
	return nil
end

function AdvancedAvatarAdapter.inspect(model: Model): {[string]: any}
	local index = indexJoints(model)
	local mapped = {}
	local missingRequired = {}
	local optionalBodyMapped = 0
	for _, semantic in Contract.bodyJointOrder do
		local aliases = Contract.aliases[semantic]
		local joint = aliases and findAlias(index, aliases) or nil
		if joint then mapped[semantic] = joint:GetFullName() end
	end
	for _, semantic in REQUIRED_R15 do
		if not mapped[semantic] then table.insert(missingRequired, semantic) end
	end
	for _, semantic in Contract.bodyJointOrder do
		if mapped[semantic] then optionalBodyMapped += 1 end
	end

	local digitCount = 0
	local digitMap = {}
	for side, fingers in Contract.digits do
		digitMap[side] = {}
		for semantic, aliases in fingers do
			local joint = findAlias(index, aliases)
			if joint then digitMap[side][semantic] = joint:GetFullName(); digitCount += 1 end
		end
	end

	local hasHumanoid = model:FindFirstChildOfClass("Humanoid") ~= nil
	local hasRigDescription = model:FindFirstChildOfClass("HumanoidRigDescription") ~= nil
	local wrapTargets = 0
	local attachments = 0
	for _, item in model:GetDescendants() do
		if item:IsA("WrapTarget") then wrapTargets += 1 end
		if item:IsA("Attachment") then attachments += 1 end
	end

	return {
		model = model.Name,
		r15Mapped = #REQUIRED_R15 - #missingRequired,
		r15Required = #REQUIRED_R15,
		missingRequired = missingRequired,
		bodyJointMapped = optionalBodyMapped,
		digitJointMapped = digitCount,
		hasHumanoid = hasHumanoid,
		hasRigDescription = hasRigDescription,
		wrapTargets = wrapTargets,
		attachments = attachments,
		adaptiveAnimationRigReady = #missingRequired == 0,
		marketplaceReady = false, -- Marketplace readiness also requires Avatar Setup validation/moderation.
		mapped = mapped,
		digits = digitMap,
	}
end

function AdvancedAvatarAdapter.tagInspection(model: Model): {[string]: any}
	local report = AdvancedAvatarAdapter.inspect(model)
	model:SetAttribute("PocketBuddyR15Mapped", report.r15Mapped)
	model:SetAttribute("PocketBuddyBodyJointsMapped", report.bodyJointMapped)
	model:SetAttribute("PocketBuddyDigitJointsMapped", report.digitJointMapped)
	model:SetAttribute("PocketBuddyAdaptiveRigReady", report.adaptiveAnimationRigReady)
	return report
end

return AdvancedAvatarAdapter
