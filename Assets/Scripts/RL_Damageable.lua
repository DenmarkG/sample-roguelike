function OnAfterSceneLoaded(self)
	self.maxHealth = 100
	self.currentHealth = self.maxHealth
	
	--modifies the current health amount
	--positive numbers will heal the character up to the max health amount
	--negative numbers will hurt the player until 0 and the character is KO'd
	--if the player's health is at or below zero, this returns true, else false
	self.ModifyHealth = function (self, amount)
	
		self.currentHealth = self.currentHealth + amount
		
		if self.currentHealth > self.maxHealth then
			self.currentHealth = self.maxHealth
		elseif self.currentHealth <= 0 then
			self.currentHealth = 0
			self.isAlive = false
			self.Die(self)
		end
	end
end
