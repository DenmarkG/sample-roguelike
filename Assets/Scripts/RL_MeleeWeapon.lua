function OnAfterSceneLoaded(self)
	--[#todo] move to onexpose once tuned
	self.attackStrength = 25
	self.meleeRange = 15
	
	self.Attack = PerformAttack
end

function OnExpose(self)
	--
end

function PerformAttack(self, enemyObj)
	Debug:PrintLine("Attacking")
	
	if enemyObj ~= nil then
		--do damamge to the enemy
	end
end

-- info fields: HitPoint, HitNormal, Force, RelativeVelocity,
--              ColliderType, ColliderObject (maybe nil)
function OnCollision(self, info)
	Debug:PrintLine("Hit Something")
	local hitType = info.ColliderType
	if hitType == "Entity" then
		if info.ColliderObject:GetKey() == "Enemy" then
			Debug:PrintLine("Hit Enemy")
		end
	end
end

function Attack(self, otherObj)
	--[[
	check to see if the other object is nil and an enemy
	if not nil and an enemyget the distance to it
	if the objet is 
	--]]
end
