--[[
Author: Denmark Gibbs
This script handles:
	--management of the creation, updating, and destruction of all spells currently in play
	
Should be attached to any character (player or enemy) that can perform spells
]]--

function OnAfterSceneLoaded(self)
	--keeps track of all spells currently active in the scene
	self.spellsInPlay = {}
	self.numSpellsInPlay = 0

	self.currentMana = self.maxMana
	
	--function to be used by other scripts to create fireballs
	self.CreateFireball = CreateNewFireball
	
	self.ModifyMana = function (self, amount)
		self.currentMana = self.currentMana + amount
		
		if self.currentMana > self.maxMana then
			self.currentMana = self.maxMana
		elseif self.currentMana < 0 then
			self.currentMana = 0
		end
	end
end

function OnExpose(self)
	--tuning variables
	self.maxMana = 100
	
	--fireball variables
	self.fireballSpeed = 25
	self.fireballRange = 500
	self.fireballManaCost = 15
	self.fireballParticlePath = "Particles\\RL_Fireball.xml"
end

function OnThink(self)
	local numSpellsInPlay = table.getn(self.spellsInPlay)
	
	--update all spells currently in the scene
	for i = 1, numSpellsInPlay, 1 do
		local currentSpell = self.spellsInPlay[i]
		if currentSpell ~= nil then
			local hitSomething = currentSpell:Update()
			if hitSomething then
				--if a fireball hit something, or it's life is up, remove it from the scene
				currentSpell.particle:Remove()
				table.remove(self.spellsInPlay, i)
				i = i - 1
			end
		end
	end
end	

function CreateNewFireball(owner, direction)
	--create the fireball (a table) and set it's values based on the exposed tuning variables
	local newFireball = {}
	newFireball.owner = owner
	newFireball.speed = owner.fireballSpeed
	newFireball.damage = owner.fireballDamage
	newFireball.range = owner.fireballRange
	newFireball.manaCost = owner.fireballManaCost
	
	--variables for updating the position
	newFireball.pos = owner:GetPosition()
	newFireball.pos.z = newFireball.pos.z + 50 --ensures it won't spawn on the ground
	newFireball.dir = direction
	newFireball.distance = 0
	
	--Creation of the Particle
	local spawnPoint = GetSpawnPoint(owner):GetPosition()
	newFireball.particle = Game:CreateEffect(spawnPoint, owner.fireballParticlePath)
	newFireball.particle:SetDirection(newFireball.dir)
	newFireball.particle:SetKey("Particle")
	
	--create the hit callback; the actions that should be done when the fireball hits something
	newFireball.HitCallBack = function(fireball, hitObj)
		local other = hitObj
		local hitKey = hitObj:GetKey()
		if other ~= nil and hitKey == "Enemy" then
			hitObj:ModifyHealth(fireball.damage)
		end
	end
	
	--how the fireball should be updated each tick
	newFireball.Update = function(fireball)
		--calculate the next position based on speed an direcion
		local nextPos = (fireball.dir * fireball.speed) + fireball.pos
		local dist = fireball.pos:getDistanceTo(nextPos)
		
		--check to see if the fireball will hit something on its path by casting a ray from the current position to the next position
		local hitObject = false
		if dist > .1 then
			local rayStart = fireball.pos
			local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
			local hit, result = Physics.PerformRaycast(rayStart, nextPos, iCollisionFilterInfo)
			
			if hit == true then
				if result ~= nil then
					if result["HitType"] == "Entity" then
						local hitObj = result["HitObject"]
						fireball:HitCallBack(hitObj)
					end
				end
				hitObject = true
			else
				--if the fireball hits nothing, move it to the next point
				fireball.distance = fireball.distance + (nextPos - fireball.pos):getLength()
				fireball.pos = nextPos
				fireball.particle:SetPosition(nextPos)
				hitObject = (fireball.distance > fireball.range)
			end
		end
		
		return hitObject
	end
	
	--add the new fireball to the array
	table.insert(owner.spellsInPlay, newFireball)
end

--this function finds the spawn point as a child of the character this script is attached to
function GetSpawnPoint(self)
	local numChildren = self:GetNumChildren()
	
	for i = 0, numChildren - 1, 1 do
		local entity = self:GetChild(i)
		
		if entity ~= nil then
			if entity:GetKey() == "ParticleSpawn" then 
				return entity
			end
		end
	end
end