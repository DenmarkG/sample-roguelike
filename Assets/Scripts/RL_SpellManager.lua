--[[
Author: Denmark Gibbs
This script handles:
	--management of the creation, updating, and destruction of all spells currently in play
	
Should be attached to any character (player or enemy) that can perform spells
]]--

--callback function that is called after the scene has been loaded but before the first Think Loop
function OnAfterSceneLoaded(self)
	--keeps track of all spells currently active in the scene
	self.spellsInPlay = {}
	self.numSpellsInPlay = 0
	
	--set the current Mana to the max mana
	self.currentMana = self.maxMana
	
	--save the sound path
	self.spellLaunchSoundPath = "Sounds/RL_SpellLauchSound.wav"
	self.spellHitSoundPath = "RL_SpellHitSound.wav"
	
	--function to be used by other scripts to create fireballs
	self.CreateFireball = CreateNewFireball
	
	--save the particle path
	self.fireballParticlePath = "Particles\\RL_Fireball.xml"
	
	--how high off the ground the fireball should spawn
	self.fireBallSpawnHeight = 50
	
	--function that modifies the mana by the amount. Used for both using and recovering mana
	self.ModifyMana = function (self, amount)
		--add the amount parameter to the current mana amount
		self.currentMana = self.currentMana + amount
		
		--clamp the mana value between the max and zero
		if self.currentMana > self.maxMana then
			self.currentMana = self.maxMana
		elseif self.currentMana < 0 then
			self.currentMana = 0
		end
	end
end

--This function allows variables to be tuned in the components window
function OnExpose(self)
	--tuning variables
	self.maxMana = 100
	
	--fireball variables
	self.fireballSpeed = 25
	self.fireballRange = 500
	self.fireballManaCost = 15
end

--callback function called once per frame
function OnThink(self)
	local numSpellsInPlay = table.getn(self.spellsInPlay)
	
	--update all spells currently in the scene
	for i = 1, numSpellsInPlay, 1 do
		local currentSpell = self.spellsInPlay[i]
		if currentSpell ~= nil then
			local hitSomething = currentSpell:Update()
			
			--if something was hit, remove this current fireball from the scene
			if hitSomething then
				--if a fireball hit something, or it's life is up, remove it from the scene
				currentSpell.particle:Remove()
				table.remove(self.spellsInPlay, i)
				i = i - 1
			end
		end
	end
end	

--function to create a new fireball. Called by the player when casting a spell
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
	newFireball.pos.z = newFireball.pos.z + owner.fireBallSpawnHeight --ensures it won't spawn on the ground
	newFireball.dir = direction
	newFireball.distance = 0
	
	--Creation of the Particle
	local spawnPoint = GetSpawnPoint(owner):GetPosition()  --set the spawn position
	newFireball.particle = Game:CreateEffect(spawnPoint, owner.fireballParticlePath)  --create the particle
	newFireball.particle:SetDirection(newFireball.dir)  --set the direction
	newFireball.particle:SetKey("Particle") --give it a key in case we need to find it later
	
	--play the launch sound if it is not nil
	local launchSound = Fmod:CreateSound(spawnPoint, owner.spellLaunchSoundPath, false)
	if launchSound ~= nil then
		launchSound:Play()
	end
	
	--create the hit callback; the actions that should be done when the fireball hits something
	newFireball.HitCallBack = function(fireball, result)
		local hitObj = result["HitObject"]
		local hitKey = hitObj:GetKey()
		if hitObj ~= nil and hitKey == "Enemy" then
			--deal damage to the entity
			hitObj:ModifyHealth(fireball.damage)
			
			--play the hit sound if it is not nil
			local hitSound = Fmod:CreateSound(result[ImpactPoint], owner.spellHitSoundPath, false)
			if hitSound ~= nil then
				hitSound:Play()
			end
		end
	end
	
	--how the fireball should be updated each frame tick
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
			
			--if fireball hits something, get the type of object 
			if hit == true then
				if result ~= nil then
					if result["HitType"] == "Entity" then
						--if the other object is an entity, invoke the fireball's Callback function (created above)
						fireball:HitCallBack(result)
					end
				end
				
				--set hitObj to true, since something was hit
				hitObject = true
			else
				--if the fireball hits nothing, move it to the next point
				fireball.distance = fireball.distance + (nextPos - fireball.pos):getLength()
				fireball.pos = nextPos
				fireball.particle:SetPosition(nextPos)
				
				--if the fireball has exceeded its max distance, then it is the same as hitting an object and this should return true
				hitObject = (fireball.distance > fireball.range)
			end
		end
		
		--return true if the fireball hit 
		return hitObject
	end
	
	--add the new fireball to the collection of all fireballs in the scene
	table.insert(owner.spellsInPlay, newFireball)
end

--this function finds the spawn point as a child of the character this script is attached to
function GetSpawnPoint(self)
	local numChildren = self:GetNumChildren()
	
	--find the spawn point by iterating through the children of this object and finding the Entity by Key
	for i = 0, numChildren - 1, 1 do
		local entity = self:GetChild(i)
		
		if entity ~= nil then
			if entity:GetKey() == "ParticleSpawn" then 
				return entity
			end
		end
	end
end