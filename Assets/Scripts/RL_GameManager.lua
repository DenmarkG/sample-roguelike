function OnAfterSceneLoaded(self)
	-- self.startTime = 60
	-- self.timeRemaining = self.startTime
end

function OnThink(self)
	-- if not G.gameOver then
		-- self.timeRemaining = self.timeRemaining - Timer:GetTimeDiff()
		-- if self.timeRemaining > 0 then
			-- ShowTimeRemaining(self)
		-- elseif self.timeRemaining <= 0 then
			-- G.gameOver = true
		-- end
	-- end
end

function ShowTimeRemaining(self)
	--set the font color for the time based on amount of time remaining
	-- local displayTime = math.ceil(self.timeRemaining)
	-- if (self.timeRemaining <= self.startTime / 2.0 or self.timeRemaining <= 20) and self.timeRemaining > 10 then
		-- Debug:PrintAt(10, 32, "Time Left: " .. displayTime, Vision.V_RGBA_YELLOW, G.fontPath)
	-- elseif self.timeRemaining <= 10 then
		-- Debug:PrintAt(10, 32, "Time Left: " .. displayTime, Vision.V_RGBA_RED, G.fontPath)
	-- else
		-- Debug:PrintAt(10, 32, "Time Left: " .. displayTime, Vision.V_RGBA_WHITE, G.fontPath)
	-- end
end