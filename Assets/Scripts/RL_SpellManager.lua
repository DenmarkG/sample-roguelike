--this script is used to manage the creation, updating, and destruction of all spells currently in play
function OnCreate(self)
	self.CreateFireball = CreateNewFireball
end

function OnAfterSceneLoaded(self)
	self.spellsInPlay = {}
	self.numSpellsInPlay = 0
	
	self.maxMana = 100
	self.currentMana = self.maxMana
	
	--#todo move these to onExpose once launch ready
	--fireball variables
	self.fireballSpeed = 25
	self.fireballDamage = -25
	self.fireballRange = 500
	self.fireballManaCost = 10
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
				currentSpell.particle:Remove()
				table.remove(self.spellsInPlay, i)
				i = i - 1
			end
		end
	end
end	

function CreateNewFireball(owner)
	local newFireball = {}
	newFireball.owner = owner
	newFireball.speed = owner.fireballSpeed
	newFireball.damage = owner.fireballDamage
	newFireball.range = owner.fireballRange
	newFireball.manaCost = owner.fireballManaCost
	--variables for updating the position
	newFireball.pos = owner:GetPosition()
	newFireball.pos.z = newFireball.pos.z + 50
	newFireball.dir = owner:GetObjDir()
	newFireball.distance = 0
	--Creation of the Particle
	newFireball.particle = Game:CreateEffect(owner:GetPosition(), owner.fireballParticlePath)
	newFireball.particle:SetDirection(newFireball.dir)
	newFireball.particle:SetKey("Particle")
	
	newFireball.HitCallBack = function(fireball, hitObj)
		local other = hitObj
		local hitKey = hitObj:GetKey()
		if other ~= nil and hitKey == "Enemy" then
			hitObj:ModifyHealth(fireball.damage)
		end
	end
	
	newFireball.Update = function(fireball)
		local nextPos = (fireball.dir * fireball.speed) + fireball.pos
		local dist = fireball.pos:getDistanceTo(nextPos)
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

function ModifyMana(self, amount)
	self.currentMana = self.currentMana + amount
	
	if self.currentMana > self.maxMana then
		self.currentMana = self.maxMana
	elseif self.currentMana < 0 then
		self.currentMana = 0
	end
end