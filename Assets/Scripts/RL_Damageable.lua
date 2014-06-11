--[[
Author: Denmark Gibbs
This script handles:
	--health of the attached character
	--calling the appropriate function of attached character if the health reaches zero
	
Should be attached to any entity (character or player) that has health
]]--


--This function allows variables to be tuned in the components window
function OnExpose(self)
	self.maxHealth = 100
end

--callback function that is called after the scene has been loaded but before the first Think Loop
function OnAfterSceneLoaded(self)
	self.currentHealth = self.maxHealth
	
	
	--[[
	here we create a function that:
		-modifies the current health amount
			-positive numbers will heal the character up to the max health amount
			-negative numbers will hurt the player until 0 and the character is KO'd
		-if the player's health is at or below zero, this returns true, else false
	--]]
	self.ModifyHealth = function (self, amount)
		--add amount parameter to the current health 
		self.currentHealth = self.currentHealth + amount
		
		if self.currentHealth > self.maxHealth then
			--if the value is greater than the max, set it to the max
			self.currentHealth = self.maxHealth
		elseif self.currentHealth <= 0 then
			--if the value is less than or equal to zero, set it to zero
			self.currentHealth = 0
			--tell the game that the player is no longer alive
			self.isAlive = false
			--call the die function on the player
			self:Die()
		end
	end
end