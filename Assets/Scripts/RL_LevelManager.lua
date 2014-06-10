--[[
Author: Denmark Gibbs
This script handles:
	--saving and loading of the Player's persistent data
	--player winning and losing
	--scene loading
	
Should be attached to a Level Manager entity in the scene
]]--

--callback function that is called after the scene has been loaded but before the first Think Loop
function OnAfterSceneLoaded(self)
	--set the Gem goal for the player to collect
	G.gemGoal = GetNumberOfGems()
	
	--create variable to keep track of if the game is over and if the player has won
	G.gameOver = false
	G.win = false
	
	--variables for re/loading a scene
	self.waitTime = 5 --time to wait before allowing the load of the next scene
	self.timeBeforeReload = 0
	
	--Load player data if not the first level (permadeath)
	if (G.currentLevel > 1) then
		LoadData(G.player)
	end
end

--callback function called automatically once per frame
function OnThink(self)
	if not G.gameOver then
		--check the win requirements to see if the player has won...
		if G.gemGoal ~= 0 and G.player.gemsCollected == G.gemGoal then
			WinLevel(self)
			G.win = true
		end
		
		--or lost
		if not G.player.isAlive then
			LoseLevel(self)
		end
	else
		--when the game is over show the player what's going on with a screen maask and text
		Debug:PrintAt( (G.w / 2.0) - (self.endText1:len() * 8), G.h / 2.0, "" .. self.endText1, Vision.V_RGBA_WHITE, G.fontPath)
		
		--count down until the player can proceed
		if self.timeBeforeReload > 0 then
			self.timeBeforeReload = self.timeBeforeReload - Timer:GetTimeDiff()
			Debug:PrintAt( (G.w / 2.0) - ((self.endText3:len() + 1) * 8), G.h / 2.0 + 32, "" .. self.endText3 .. math.ceil(self.timeBeforeReload), Vision.V_RGBA_WHITE, G.fontPath)
		elseif self.timeBeforeReload < 0 then
			self.timeBeforeReload = 0
		end
		
		--allow the player to proceed by tapping the screen or clicking
		if self.timeBeforeReload <= 0 then
			Debug:PrintAt( (G.w / 2.0) - (self.endText2:len() * 8), G.h / 2.0 + 32, "" .. self.endText2, Vision.V_RGBA_WHITE, G.fontPath)
			
			--the player can't continue until a specific button is pressed (varies by platform)
			local continue = false
			if G.isWindows then
				continue = G.player.map:GetTrigger("MELEE") > 0
			else
				continue = G.player.map:GetTrigger("CLICK") > 0
			end
			
			--load the next level or reload the first depending on the win condition
			if continue then
				if G.win and G.currentLevel ~= G.maxLevelCount then
					--save the data before loading a new level
					SaveData(G.player)
					G.player:SaveInventory()
					LoadNextLevel()
				else
					LoadFirstLevel()
				end
			end
		end
	end
end

--finds the total number of Gems in the scene
--this is necessary to know how many the player should collect to finish the level
function GetNumberOfGems()
	--initialize the total amount of gems (the goal amount) to zero
	local gemGoal = 0
	
	--all the gems are children of the gem parent, so find the gem parent first
	local gemParent = Game:GetEntity("GemParent")
	
	--iterate through the children of the gem parent and count the number of gems
	if gemParent ~= nil then
		for i = 0, gemParent:GetNumChildren(), 1 do
			--cache the currently selected child of the gem parent
			local entity = gemParent:GetChild(i)
			
			--only add increase the amount if the entity's key is "Gem"
			if entity ~= nil and entity:GetKey() == "Gem" then
				gemGoal = gemGoal + 1
			end
		end
		--return the number of gems found
		return gemGoal
	else
		--if the gem parent was not found, this will return 0
		return 0
	end
end

--this function is called when the game is over and the player has collected all gems
function WinLevel(self)
	--Show the Win Screen and tell the player when s/he can play again
	self.endText1 = "You Win!"
	self.endText2 = ""
	
	--the message to display varies based on platform since the continue command is also different
	if G.isWindows then
		self.endText2 = "   Press \'MELEE\' To Continue"
	else
		self.endText2 = "   Touch Screen To Continue "
	end
	
	self.endText3 = "    Play Again in: "
	
	--set the game state to game over
	G.gameOver = true
	
	--cover the screen with mask the size of the screen area
	G.winMask = Game:CreateScreenMask(0, 0, "Textures/RL_WinScreenMask_DIFFUSE.tga")
	G.winMask:SetTargetSize(G.w, G.h)
	G.winMask:SetBlending(Vision.BLEND_MULTIPLY)
	
	--start the countdown Timer
	StartTimer(self)
end

--called when the game is over
--sets the time to reload to the wait time
function StartTimer(self)
	self.timeBeforeReload = self.waitTime
end

--this is called if the player dies before collecting all gems
function LoseLevel(self)
	--Show the Win Screen and tell the player when s/he can play again
	self.endText1 = "You Lose!"
	self.endText2 = ""
	
	--the message to display varies based on platform since the continue command is also different
	if G.isWindows then
		self.endText2 = "Press \'MELEE\' To Continue"
	else
		self.endText2 = "Touch Screen To Continue "
	end
	
	self.endText3 = "Play Again in: "

	--set the game state to game over
	G.gameOver = true
	
	--cover the screen with mask the size of the screen area
	G.winMask = Game:CreateScreenMask(0, 0, "Textures/RL_WinScreenMask_DIFFUSE.tga")
	G.winMask:SetTargetSize(G.w, G.h)
	G.winMask:SetBlending(Vision.BLEND_MULTIPLY)
	
	--empty the player's inventory
	G.player:Clear()
	
	--start the countdown Timer
	StartTimer(self)
end

--this function loads the next level in the sequence
function LoadNextLevel()
	--increase the current level
	G.currentLevel = G.currentLevel + 1
	
	--then call the function to load the next level based on platform
	if G.isWindows then
		Application:LoadScene("Scenes/sample-level0"..G.currentLevel..".pcdx9.vscene")
	else
		Application:LoadScene("Scenes/sample-level0"..G.currentLevel..".android.vscene")
	end
end

--loads the first level when the player dies or has completed all levels
function LoadFirstLevel()
	--set the current level to 1
	G.currentLevel = 1
	
	--load the level based on the platform
	if G.isWindows then
		Application:LoadScene("Scenes/sample.pcdx9.vscene")
	else
		Application:LoadScene("Scenes/sample.android.vscene")
	end
end

--[[
called if the player has reached a level after 1.
Loads data that was previously saved at the end of the previous levels
--]]
function LoadData(player)
	--if data has not already been loaded, load the existing data
	PersistentData:Load("PlayerStats")
	
	-- load the player stats:
	--load the data for each category. The defaults are in place in the event the data does not load properly
	player.currentHealth = PersistentData:GetNumber("PlayerStats", "health", 17)--defaulting to 17 to show somehting went wrongs
	player.currentMana = PersistentData:GetNumber("PlayerStats", "mana", 17) 
	player.meleeDamage = PersistentData:GetNumber("PlayerStats", "attack", 7)
	player.fireballDamage = PersistentData:GetNumber("PlayerStats", "magic", 7)
end

--[[
saves the player items, health, mana, and attack power at the end of the level.
--]]
function SaveData(player)
	--save player info for each category:
	PersistentData:SetNumber("PlayerStats", "health", player.currentHealth)
	PersistentData:SetNumber("PlayerStats", "mana", player.currentMana)
	PersistentData:SetNumber("PlayerStats", "attack", player.meleeDamage)
	PersistentData:SetNumber("PlayerStats", "magic", player.fireballDamage)

	--Output all files
	PersistentData:SaveAll()
end