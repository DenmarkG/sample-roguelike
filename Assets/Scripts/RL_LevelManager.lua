function OnAfterSceneLoaded(self)
	G.gemGoal = GetNumberOfGems()
	G.gameOver = false
	
	self.waitTime = 5
	self.timeBeforeReload = 0
	
	G.Lose = LoseLevel
	G.Win = WinLevel
end

function OnThink(self)
	if not G.gameOver then
		if G.player.gemsCollected == G.gemGoal then
			WinLevel(self)
		end
		
		if not G.player.isAlive then
			LoseLevel(self)
		end
	else
		Debug:PrintAt( (G.w / 2.0) - (self.endText1:len() * 8), G.h / 2.0, "" .. self.endText1, Vision.V_RGBA_WHITE, G.fontPath)
		
		if self.timeBeforeReload > 0 then
			self.timeBeforeReload = self.timeBeforeReload - Timer:GetTimeDiff()
			Debug:PrintAt( (G.w / 2.0) - ((self.endText3:len() + 1) * 8), G.h / 2.0 + 32, "" .. self.endText3 .. math.ceil(self.timeBeforeReload), Vision.V_RGBA_WHITE, G.fontPath)
		elseif self.timeBeforeReload < 0 then
			self.timeBeforeReload = 0
		end
		
		if self.timeBeforeReload <= 0 then
			Debug:PrintAt( (G.w / 2.0) - (self.endText2:len() * 8), G.h / 2.0 + 32, "" .. self.endText2, Vision.V_RGBA_WHITE, G.fontPath)
			
			if (G.player.map:GetTrigger("MELEE") > 0 or G.player.map:GetTrigger("X") ~= 0) then
				ResetGame()
			end
		end
	end
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
	--Show the Win Screen and tell the player when s/he can play again
	self.endText1 = "You Win!"
	self.endText2 = ""
	
	if G.isWindows then
		self.endText2 = "Press \'MELEE\' To Continue"
	else
		self.endText2 = "Touch Screen To Continue "
	end
	
	self.endText3 = "Play Again in: "

	G.gameOver = true
	G.winMask = Game:CreateScreenMask(0, 0, "Textures/RL_WinScreenMask_DIFFUSE.tga")
	G.winMask:SetTargetSize(G.w, G.h)
	G.winMask:SetBlending(Vision.BLEND_MULTIPLY)
	
	StartTimer(self)
end

function StartTimer(self)
	self.timeBeforeReload = self.waitTime
end

function LoseLevel(self)
	--Show the Win Screen and tell the player when s/he can play again
	self.endText1 = "You Lose!"
	self.endText2 = ""
	
	if G.isWindows then
		self.endText2 = "Press \'MELEE\' To Continue"
	else
		self.endText2 = "Touch Screen To Continue "
	end
	
	self.endText3 = "Play Again in: "

	G.gameOver = true
	G.winMask = Game:CreateScreenMask(0, 0, "Textures/RL_WinScreenMask_DIFFUSE.tga")
	G.winMask:SetTargetSize(G.w, G.h)
	G.winMask:SetBlending(Vision.BLEND_MULTIPLY)
	
	StartTimer(self)
end

function ResetGame()
	--load new level here
end