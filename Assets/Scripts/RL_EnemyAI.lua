-- new script file
function OnAfterSceneLoaded(self)
	--get the character controller attched to this or assign one if nil
	self.characterController = self:GetComponentOfType("vHavokCharacterController")
	if self.characterController == nil then
		self.AddComponentOfType("vHavokCharacterController")
	end
	
	--tuning variables
	self.chaseSpeed = 50 --how fast this character should move when chasing the player	
	self.patrolSpeed = 30 --how fast this NPC should move when patrolling
	self.attackRange = 60 --how close the NPC should get before attacking
	self.sightRange = 500 --how far the enemy can see a player
	self.viewingAngle = 60 --the angle that the NPC can see within
	self.numSightRays = 5	--the number of rays to cast within the veiwing angle to look for the player
	self.eyeHeight = 50
end

function OnThink(self)
	if not G.gameOver and G.player ~= nil then
		local playerSighted = LookForPlayer(self)
		if playerSighted then
			--cache the time difference
			local dt = Timer:GetTimeDiff()
			
			--get the this and the player's position
			local playerPosition = G.player:GetPosition()
			local myPosition = self:GetPosition()
			--get the distance to the player
			local distance = myPosition:getDistanceTo(playerPosition)
			
			--if out of attack range, move closer
			if  distance > self.attackRange then
				--if out of range, find path and move closer to player
				local path = AI:FindPath(myPosition, playerPosition, 20)
				if path ~= nil then
					local numPoints = table.getn(path)
					local endPoint = path[numPoints]
					self.path = path
					self.pathProgress = 0
					self.pathLength = AI:GetPathLength(path)
				else
					Debug:PrintLine("No PathFound")
				end
				
				if self.path then
					self.pathProgress = self.pathProgress + dt * self.chaseSpeed

					if self.pathProgress > self.pathLength then
						self.pathProgress = self.pathLength
					end
					
					local point = AI:GetPointOnPath(self.path, self.pathProgress)
					local dir = point - myPosition
					self:SetMotionDeltaWorldSpace(dir)

					if self.pathProgress == self.pathLength then
						self.path = nil
					end
				end	
			end
		end
	end
end

--[[
returns true if the player is in range and unblocked, false otherwise
--]]

function LookForPlayer(self)
	for i = -(self.numSightRays / 2), self.numSightRays / 2, 1 do
		--cast a rays within the viewing angle
		--local rayDir = ( (self.viewingAngle / self.numSightRays) * i) + 
		
		local rayStart = self:GetPosition()
		rayStart.z = self.eyeHeight
		local rayEnd = (self:GetObjDir() * self.sightRange) + rayStart
	
		local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
		local hit, result = Physics.PerformRaycast(rayStart, rayEnd, iCollisionFilterInfo)
		
		local color = Vision.V_RGBA_BLUE
		Debug.Draw:Line(rayStart, rayEnd, color)
		
		--get the collision info
		local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
		local hit, result = Physics.PerformRaycast(rayStart, rayEnd, iCollisionFilterInfo)
	
		if hit == true then
			--check to see if a target was hit
			if result ~= nil and result["HitType"] == "Entity" then
				local hitObj = result["HitObject"]
				if hitObj:GetKey() == "Target" then
					Debug:PrintLint("hit: " .. hitObj:GetKey() )
					return true
				end
			end
		end
	end
	
	return false
end