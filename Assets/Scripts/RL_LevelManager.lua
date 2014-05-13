function OnAfterSceneLoaded(self)
	G.gemsCollected = 0
	G.GemGoal = GetNumberOfGems()
	G.gameOver = false
end

function OnThink(self)
	--
end

function GetNumberOfGems()
	local gemGoal = 0
	local gemParent = Game:GetEntity("GemParent")
	
	for i = 0, gemParent:GetNumChildren(), 1 do
		local entity = gemParent:GetChild(i)
		
		if entity ~= nil and entity:GetKey() == "Gem" then
			gemGoal = gemGoal + 1
		end
	end
	
	return gemGoal
end

function WinLevel(self)
	--
end

function LoseLevel(self)
	--
end