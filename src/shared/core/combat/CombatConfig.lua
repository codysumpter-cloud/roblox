--!strict

return {
	ComboResetSeconds = 0.85,
	PerfectBlockWindow = 0.16,
	GuardMax = 100,
	GuardRegenPerSecond = 18,
	GuardRegenDelay = 1.2,
	DashCooldown = 0.8,
	DashImpulse = 52,
	LauncherCooldown = 1.4,
	Targeting = {
		MaxRange = 28,
		SoftConeDegrees = 68,
		HardConeDegrees = 150,
		ScreenWeight = 0.42,
		AngleWeight = 0.33,
		DistanceWeight = 0.25,
		CurrentTargetBonus = 0.18,
	},
	LightCombo = {
		{ Damage = 6, GuardDamage = 10, Stun = 0.22, Knockback = 7, Width = 5.5, Height = 5.5, Depth = 6.0, ForwardOffset = 3.2 },
		{ Damage = 6, GuardDamage = 10, Stun = 0.24, Knockback = 8, Width = 5.7, Height = 5.5, Depth = 6.2, ForwardOffset = 3.3 },
		{ Damage = 7, GuardDamage = 12, Stun = 0.28, Knockback = 10, Width = 6.0, Height = 5.8, Depth = 6.4, ForwardOffset = 3.5 },
		{ Damage = 10, GuardDamage = 20, Stun = 0.42, Knockback = 34, Width = 6.4, Height = 6.0, Depth = 7.0, ForwardOffset = 3.8, Ragdoll = 0.55 },
	},
	Launcher = {
		Damage = 9,
		GuardDamage = 24,
		Stun = 0.38,
		Knockback = 10,
		VerticalImpulse = 42,
		Width = 5.8,
		Height = 6.5,
		Depth = 6.2,
		ForwardOffset = 3.3,
	},
}
