--!strict
-- Portable naming/semantic data for adapting Prismtek One Rig / UEFN-style rigs
-- to Roblox HumanoidRigDescription + DigitsRigDescription.
-- No Roblox services or Instances belong in this module.

return {
	bodyJointOrder = {
		"Root", "Waist", "Spine", "Chest", "Neck", "HeadBase",
		"LeftClavicle", "LeftShoulder", "LeftElbow", "LeftWrist",
		"RightClavicle", "RightShoulder", "RightElbow", "RightWrist",
		"LeftHip", "LeftKnee", "LeftAnkle", "LeftToeBase",
		"RightHip", "RightKnee", "RightAnkle", "RightToeBase",
	},

	-- First match wins. The aliases cover Roblox, Prismtek One Rig/Godot humanoid,
	-- VRoid-ish humanoid names, and the UEFN donor family used by GASP.
	aliases = {
		Root = { "Root", "root" },
		Waist = { "Waist", "Hips", "pelvis" },
		Spine = { "Spine", "spine_01" },
		Chest = { "Chest", "UpperChest", "spine_03", "spine_05" },
		Neck = { "Neck", "neck_01" },
		HeadBase = { "HeadBase", "Head", "head" },
		LeftClavicle = { "LeftClavicle", "LeftShoulder", "clavicle_l" },
		LeftShoulder = { "LeftShoulder", "LeftUpperArm", "upperarm_l" },
		LeftElbow = { "LeftElbow", "LeftLowerArm", "lowerarm_l" },
		LeftWrist = { "LeftWrist", "LeftHand", "hand_l" },
		RightClavicle = { "RightClavicle", "RightShoulder", "clavicle_r" },
		RightShoulder = { "RightShoulder", "RightUpperArm", "upperarm_r" },
		RightElbow = { "RightElbow", "RightLowerArm", "lowerarm_r" },
		RightWrist = { "RightWrist", "RightHand", "hand_r" },
		LeftHip = { "LeftHip", "LeftUpperLeg", "thigh_l" },
		LeftKnee = { "LeftKnee", "LeftLowerLeg", "calf_l" },
		LeftAnkle = { "LeftAnkle", "LeftFoot", "foot_l" },
		LeftToeBase = { "LeftToeBase", "LeftToes", "ball_l" },
		RightHip = { "RightHip", "RightUpperLeg", "thigh_r" },
		RightKnee = { "RightKnee", "RightLowerLeg", "calf_r" },
		RightAnkle = { "RightAnkle", "RightFoot", "foot_r" },
		RightToeBase = { "RightToeBase", "RightToes", "ball_r" },
	},

	-- DigitsRigDescription exposes Thumb1..3, Index1..3, Middle1..3,
	-- Ring1..3 and Pinky1..3 for each side. Metacarpals/twist/IK/weapon/marker
	-- bones may remain on source/donor rigs but are not required Roblox mappings.
	digits = {
		Left = {
			Thumb1 = { "LeftThumbMetacarpal", "LeftThumbProximal", "thumb_01_l" },
			Thumb2 = { "LeftThumbProximal", "thumb_02_l" },
			Thumb3 = { "LeftThumbDistal", "thumb_03_l" },
			Index1 = { "LeftIndexProximal", "index_01_l" }, Index2 = { "LeftIndexIntermediate", "index_02_l" }, Index3 = { "LeftIndexDistal", "index_03_l" },
			Middle1 = { "LeftMiddleProximal", "middle_01_l" }, Middle2 = { "LeftMiddleIntermediate", "middle_02_l" }, Middle3 = { "LeftMiddleDistal", "middle_03_l" },
			Ring1 = { "LeftRingProximal", "ring_01_l" }, Ring2 = { "LeftRingIntermediate", "ring_02_l" }, Ring3 = { "LeftRingDistal", "ring_03_l" },
			Pinky1 = { "LeftLittleProximal", "pinky_01_l" }, Pinky2 = { "LeftLittleIntermediate", "pinky_02_l" }, Pinky3 = { "LeftLittleDistal", "pinky_03_l" },
		},
		Right = {
			Thumb1 = { "RightThumbMetacarpal", "RightThumbProximal", "thumb_01_r" },
			Thumb2 = { "RightThumbProximal", "thumb_02_r" },
			Thumb3 = { "RightThumbDistal", "thumb_03_r" },
			Index1 = { "RightIndexProximal", "index_01_r" }, Index2 = { "RightIndexIntermediate", "index_02_r" }, Index3 = { "RightIndexDistal", "index_03_r" },
			Middle1 = { "RightMiddleProximal", "middle_01_r" }, Middle2 = { "RightMiddleIntermediate", "middle_02_r" }, Middle3 = { "RightMiddleDistal", "middle_03_r" },
			Ring1 = { "RightRingProximal", "ring_01_r" }, Ring2 = { "RightRingIntermediate", "ring_02_r" }, Ring3 = { "RightRingDistal", "ring_03_r" },
			Pinky1 = { "RightLittleProximal", "pinky_01_r" }, Pinky2 = { "RightLittleIntermediate", "pinky_02_r" }, Pinky3 = { "RightLittleDistal", "pinky_03_r" },
		},
	},

	sourceOnlyPrefixes = { "ik_", "weapon_", "VB ", "props_", "prop_", "attach", "poi" },
}
