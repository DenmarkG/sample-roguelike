--[[
Author: Denmark Gibbs
This script handles:
	-Calling the appropriate function to end the level when the player hits the trigger this is attached to
]]--

function OnAfterSceneLoaded(self)
	G.levelManager = Game:GetEntity("LevelManager")
end

--This callback function is called whenever an object (otherObj) enters the trigger that this script is attached to.
--In the case of this script, it will call the function to trigger the end of the level.
function OnObjectEnter(self, otherObj)
	--if hte object that enters the trigger is the player, add this item to the player's inventory
	if otherObj:GetKey() == "Player" then
		G.WinThisLevel(G.levelManager)
	end
end