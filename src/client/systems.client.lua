--!strict
local AdminController = require(script.Parent.AdminController)
local WorldEventController = require(script.Parent.WorldEventController)
local GaspHumanoidController = require(script.Parent.GaspHumanoidController)

AdminController.start()
WorldEventController.start()
GaspHumanoidController.start()

print("[PocketBuddy] optional systems started: admin, world events, GASP humanoid adapter")
