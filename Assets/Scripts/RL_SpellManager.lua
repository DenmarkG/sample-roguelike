-- new script file
function OnAfterSceneLoaded(self)
	G.fireballs = {}
	G.CreateFireball = CreateNewFireball
end

function OnThink(self)
	local numFireBalls = table.getn(G.fireballs)
	
	--for each bullet, update it's position and delete if necessary
	if numFireBalls > 0 then
		for i = 1, numFireBalls, 1 do
			local fireball = G.fireballs[i]
			if fireball ~= nil then 
				--if the udate bullet function returns true, delete the bullet ***won't be true if bullet ricochets
				if UpdateFireball(fireball) then
					fireball.particle:Remove()
					table.remove(G.fireballs, i)
					--decrement i since the size of the table has decreased by 1
					i = i - 1
				end
			end	
		end
	end
end	

function CreateNewFireball(owner)
	local spellParticle = Game:CreateEffect(owner:GetPosition(), owner.fireballPath)
	spellParticle:SetDirection(owner:GetObjDir() )
	
	local newFireball = {}
	newFireball.speed = owner.fireballSpeed
	newFireball.damage = owner.fireballDamage
	newFireball.range = owner.fireballRange
	newFireball.startPos = owner:GetPosition()
	newFireball.pos = newFireball.startPos
	newFireball.distance = 0
	newFireball.owner = owner
	newFireball.dir = owner:GetObjDir()
	
	newFireball.HitCallBack = function(fireball, hitObj)
		if hitObj ~= nil and hitObj:GetKey() == "Enemy" then
			--
		end
	end
	
	--add the new fireball to the array
	table.insert(G.fireballs, newFireball)
end

function UpdateFireball(fireball)
	local nextPos = (fireball.dir * fireball.speed) + fireball.pos
	
	local dist = fireball.pos:getDistanceTo(nextPos)
	
	local hitObject = false
	
	if dist > .1 then
		local raystart = fireball.pos
		
		local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
		local hit, result = Physics.PerformRaycast(rayStart, nextPos, iCollisionFilterInfo)
		
		if hit == true then
			if result ~= nil then
				if result["HitType"] == "Entity" then
					local hitObj = result["HitOjbect"]
					fireball:HitCallBack(hitObj)
				end
			end
			
			hitObject = true
		else
			fireball.distance = fireball + (nextPos - fireball.pos):GetLength()
			
			fireball.pos = nextPos
			bullet.particle:SetPosition(nextPos)
			
			hitObject = (fireball.distance > fireball.range)
		end
	end
	
	return hitObject
end