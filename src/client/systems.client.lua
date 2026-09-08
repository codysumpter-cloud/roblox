--!strict
local AdminController = require(script.Parent.AdminController)
local WorldEventController = require(script.Parent.WorldEventController)
local GaspHumanoidController = require(script.Parent.GaspHumanoidController)
local CombatController = require(script.Parent.CombatController)

AdminController.start()
WorldEventController.start()
GaspHumanoidController.start()
CombatController.start()

print("[PocketBuddy] optional systems started: admin, world events, GASP humanoid adapter, PvP combat")
