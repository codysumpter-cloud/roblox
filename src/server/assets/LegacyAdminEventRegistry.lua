--!strict
-- Explicit allowlist for Studio-managed Admin V5 event packages that are allowed
-- to execute server-side. Nothing outside this registry is ever launched.
--
-- The source package stays in ServerStorage. LegacyAdminEventService clones only
-- the selected package into a runnable server container after an authorized admin
-- requests it, then removes the runtime clone when the event ends.

return {
	RainingTacos = {
		displayName = "Raining Tacos",
		aliases = {
			"raining tacos",
			"rainingtacos",
			"raining_tacos",
			"taco rain",
			"tacorain",
		},
		-- Admin V5 packs are not Rojo-managed, so tolerate a few likely parent names
		-- while still requiring the event package itself to match an approved alias.
		preferredRootAliases = {
			"admin v5",
			"adminv5",
			"admin panel v5",
			"adminpanelv5",
		},
		maxRuntimeSeconds = 180,
		maxScripts = 48,
	},
}
