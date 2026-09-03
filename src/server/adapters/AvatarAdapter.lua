--!strict
local AvatarAdapter = {}

function AvatarAdapter.setCharacterVisible(character: Model, visible: boolean)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant.Name ~= "HumanoidRootPart" then
				descendant.Transparency = visible and 0 or 1
			end
		elseif descendant:IsA("Decal") then
			descendant.Transparency = visible and 0 or 1
		end
	end
end

-- Party-mode control swapping belongs here when implemented. Hub mode must leave the player's
-- normal Roblox avatar intact; party mode may temporarily hide/freeze it while the selected pet is
-- controlled, then restore it on exit.
return AvatarAdapter
