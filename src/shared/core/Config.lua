--!strict
return {
	SchemaVersion = 1,
	BuildDemoWorld = true,
	-- Published private Studio tests can opt into DataStore access. If API access is
	-- disabled, the adapter falls back to a session profile and refuses to overwrite it.
	PersistInStudio = true,
	NeedTickSeconds = 30,
	NeedDecayPerTick = 1,
	InteractionCooldown = 0.25,
	MaxPets = 100,
	StarterPetSeedSalt = 7919,
}
