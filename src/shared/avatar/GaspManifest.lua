--!strict
-- Portable semantic contract shared with the Godot GASP integration.
-- This file intentionally contains no Roblox services or Instances.

return {
	schemaVersion = 1,
	donor = "GASP_58_UEFN_Mannequin",
	canonicalSkeleton = "SK_UEFN_Mannequin",
	clips = {
		idle = "M_Neutral_Stand_Idle_Loop",
		walk = "M_Neutral_Walk_Loop_F",
		jog = "M_Neutral_Run_Loop_F",
		run = "M_Neutral_Run_Loop_F",
		sprint = "M_Neutral_Sprint_Loop_F",
		start = "M_Neutral_Run_Start_F_Lfoot",
		stop = "M_Neutral_Run_Stop_F_Lfoot",
		pivot_left = "M_Neutral_Run_Pivot_FL_BR_Lfoot",
		pivot_right = "M_Neutral_Run_Pivot_FR_BL_Rfoot",
		jump = "M_Neutral_Jump_F_Start_Run_Lfoot",
		fall = "M_Neutral_Jump_Loop_Fall",
		land = "M_Neutral_Jump_F_Land_Stand_Light_Lfoot",
		hurdle = "M_Neutral_Traversal_Catch_Hurdle_med_run",
		vault_low = "M_Neutral_Traversal_Catch_Vault_low",
		vault_high = "M_Neutral_Traversal_Catch_Vault_high",
		mantle = "M_Neutral_Traversal_Catch_Mantle_med_run",
	},
	looping = {
		idle = true,
		walk = true,
		jog = true,
		run = true,
		sprint = true,
		fall = true,
	},
	requiredLocomotion = { "idle", "walk", "jog", "sprint", "jump", "fall", "land" },
	optionalTransitions = { "start", "stop", "pivot_left", "pivot_right" },
	traversal = { "hurdle", "vault_low", "vault_high", "mantle" },
}
