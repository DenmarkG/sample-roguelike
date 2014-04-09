function OnAfterSceneLoaded
	self.maxMana = 100
	self.currentMana = self.maxMana
end

function OnExpose

end

function ModifyMana(self, amount)
	self.currentMana = self.currentMana + amount
	
	if self.currentMana > self.maxMana then
		self.currentMana = self.maxMana
	elseif self.currentMana < 0 then
		self.currentMana = 0
	end
end