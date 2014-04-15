function OnAfterSceneLoaded(self)
	--[#todo] move to onexpose once tuned
	self.attackStrength = 25
	self.meleeRange = 15

	
	self.SetUp = SetUpWeapon
	self.Attack = PerformAttack
end

function OnExpose(self)
	--
end

function OnThink(self)
	--
end

function SetUpWeapon(self)
	--
end

function PerformAttack(self, enemyObj)
	Debug:PrintLine("Attacking")
	
	if enemyObj ~= nil then
		--do damamge to the enemy
	end
end