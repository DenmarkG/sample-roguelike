function OnAfterSceneLoaded(self)
	self.maxHealth = 100
	self.currentHealth = self.maxHealth
end

function OnExpose(self)

end

function ModifyHealth(self, amount)
	self.currentHealth = self.currentHealth + amount
	
	if self.currentHealth > self.maxHealth then
		self.currentHealth = self.maxHealth
	elseif self.currentHealth < 0 then
		self.currentHealth = 0
	end
end