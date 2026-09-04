--!strict
-- Portable naming/semantic data for adapting Prismtek One Rig / VRoid / UEFN-style
-- rigs to Roblox HumanoidRigDescription + DigitsRigDescription.
-- No Roblox services or Instances belong in this module.

return {
	bodyJointOrder = {
		"Root", "Waist", "Spine", "Chest", "Neck", "HeadBase",
		"LeftClavicle", "LeftShoulder", "LeftElbow", "LeftWrist",
		"RightClavicle", "RightShoulder", "RightElbow", "RightWrist",
		"LeftHip", "LeftKnee", "LeftAnkle", "LeftToeBase",
		"RightHip", "RightKnee", "RightAnkle", "RightToeBase",
	},

	-- First match wins. Optional Advanced R15 joints are intentionally not
	-- aliased to a neighboring standard joint: if a source has no clavicle or
	-- HeadBase joint, the report must say so instead of inflating coverage.
	aliases = {
		Root = { "Root", "root" },
		Waist = { "Waist", "Hips", "pelvis", "J_Bip_C_Hips" },
		Spine = { "Spine", "spine_01", "J_Bip_C_Spine" },
		Chest = { "Chest", "UpperChest", "spine_03", "spine_05", "J_Bip_C_Chest", "J_Bip_C_UpperChest" },
		Neck = { "Neck", "neck_01", "J_Bip_C_Neck" },
		HeadBase = { "HeadBase" },
		LeftClavicle = { "LeftClavicle", "clavicle_l", "J_Bip_L_Shoulder" },
		LeftShoulder = { "LeftShoulder", "LeftUpperArm", "upperarm_l", "J_Bip_L_UpperArm" },
		LeftElbow = { "LeftElbow", "LeftLowerArm", "lowerarm_l", "J_Bip_L_LowerArm" },
		LeftWrist = { "LeftWrist", "LeftHand", "hand_l", "J_Bip_L_Hand" },
		RightClavicle = { "RightClavicle", "clavicle_r", "J_Bip_R_Shoulder" },
		RightShoulder = { "RightShoulder", "RightUpperArm", "upperarm_r", "J_Bip_R_UpperArm" },
		RightElbow = { "RightElbow", "RightLowerArm", "lowerarm_r", "J_Bip_R_LowerArm" },
		RightWrist = { "RightWrist", "RightHand", "hand_r", "J_Bip_R_Hand" },
		LeftHip = { "LeftHip", "LeftUpperLeg", "thigh_l", "J_Bip_L_UpperLeg" },
		LeftKnee = { "LeftKnee", "LeftLowerLeg", "calf_l", "J_Bip_L_LowerLeg" },
		LeftAnkle = { "LeftAnkle", "LeftFoot", "foot_l", "J_Bip_L_Foot" },
		LeftToeBase = { "LeftToeBase", "LeftToes", "ball_l", "J_Bip_L_ToeBase" },
		RightHip = { "RightHip", "RightUpperLeg", "thigh_r", "J_Bip_R_UpperLeg" },
		RightKnee = { "RightKnee", "RightLowerLeg", "calf_r", "J_Bip_R_LowerLeg" },
		RightAnkle = { "RightAnkle", "RightFoot", "foot_r", "J_Bip_R_Foot" },
		RightToeBase = { "RightToeBase", "RightToes", "ball_r", "J_Bip_R_ToeBase" },
	},

	-- DigitsRigDescription exposes Thumb1..3, Index1..3, Middle1..3,
	-- Ring1..3 and Pinky1..3 for each side. UEFN metacarpals/twist/IK/weapon/
	-- marker bones may remain on source/donor rigs but are not required mappings.
	digits = {
		Left = {
			Thumb1 = { "LeftThumbMetacarpal", "LeftThumbProximal", "thumb_01_l", "J_Bip_L_Thumb1" },
			Thumb2 = { "LeftThumbProximal", "thumb_02_l", "J_Bip_L_Thumb2" },
			Thumb3 = { "LeftThumbDistal", "thumb_03_l", "J_Bip_L_Thumb3" },
			Index1 = { "LeftIndexProximal", "index_01_l", "J_Bip_L_Index1" }, Index2 = { "LeftIndexIntermediate", "index_02_l", "J_Bip_L_Index2" }, Index3 = { "LeftIndexDistal", "index_03_l", "J_Bip_L_Index3" },
			Middle1 = { "LeftMiddleProximal", "middle_01_l", "J_Bip_L_Middle1" }, Middle2 = { "LeftMiddleIntermediate", "middle_02_l", "J_Bip_L_Middle2" }, Middle3 = { "LeftMiddleDistal", "middle_03_l", "J_Bip_L_Middle3" },
			Ring1 = { "LeftRingProximal", "ring_01_l", "J_Bip_L_Ring1" }, Ring2 = { "LeftRingIntermediate", "ring_02_l", "J_Bip_L_Ring2" }, Ring3 = { "LeftRingDistal", "ring_03_l", "J_Bip_L_Ring3" },
			Pinky1 = { "LeftLittleProximal", "pinky_01_l", "J_Bip_L_Little1" }, Pinky2 = { "LeftLittleIntermediate", "pinky_02_l", "J_Bip_L_Little2" }, Pinky3 = { "LeftLittleDistal", "pinky_03_l", "J_Bip_L_Little3" },
		},
		Right = {
			Thumb1 = { "RightThumbMetacarpal", "RightThumbProximal", "thumb_01_r", "J_Bip_R_Thumb1" },
			Thumb2 = { "RightThumbProximal", "thumb_02_r", "J_Bip_R_Thumb2" },
			Thumb3 = { "RightThumbDistal", "thumb_03_r", "J_Bip_R_Thumb3" },
			Index1 = { "RightIndexProximal", "index_01_r", "J_Bip_R_Index1" }, Index2 = { "RightIndexIntermediate", "index_02_r", "J_Bip_R_Index2" }, Index3 = { "RightIndexDistal", "index_03_r", "J_Bip_R_Index3" },
			Middle1 = { "RightMiddleProximal", "middle_01_r", "J_Bip_R_Middle1" }, Middle2 = { "RightMiddleIntermediate", "middle_02_r", "J_Bip_R_Middle2" }, Middle3 = { "RightMiddleDistal", "middle_03_r", "J_Bip_R_Middle3" },
			Ring1 = { "RightRingProximal", "ring_01_r", "J_Bip_R_Ring1" }, Ring2 = { "RightRingIntermediate", "ring_02_r", "J_Bip_R_Ring2" }, Ring3 = { "RightRingDistal", "ring_03_r", "J_Bip_R_Ring3" },
			Pinky1 = { "RightLittleProximal", "pinky_01_r", "J_Bip_R_Little1" }, Pinky2 = { "RightLittleIntermediate", "pinky_02_r", "J_Bip_R_Little2" }, Pinky3 = { "RightLittleDistal", "pinky_03_r", "J_Bip_R_Little3" },
		},
	},

	sourceOnlyPrefixes = { "ik_", "weapon_", "VB ", "props_", "prop_", "attach", "poi" },
}
