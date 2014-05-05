-- new script file
function OnAfterSceneLoaded(self)
	self.rigidBody = self:GetComponentOfType("vHavokRigidBody")
	if self.rigidBody == nil then
		self.rigidBody = self:AddComponentOfType("vHavokRigidBody")
	end
		
	--tuning variables
	self.chaseSpeed = 50 --how fast this character should move when chasing the player	
	self.patrolSpeed = 2.5 --how fast this NPC should move when patrolling
	self.rotSpeed = 10
	self.attackRange = 60 --how close the NPC should get before attacking
	self.sightRange = 500 --how far the enemy can see a player
	self.viewingAngle = 60 --the angle that the NPC can see within
	self.numSightRays = 5	--the number of rays to cast within the veiwing angle to look for the player
	self.eyeHeight = 50
	
	self.localTimeScale = 1
end

function OnThink(self)
	self.dt = Timer:GetTimeDiff() *  self.localTimeScale 

	if not G.gameOver and G.player ~= nil then
		if LookForPlayer(self) then
			FindPath(self)
		end
		
		-- FindPath(self)
		
		--debugging
		local color = Vision.V_RGBA_RED
		local start = self:GetPosition()
		local rEnd = (self:GetObjDir() * 100) + start
		Debug.Draw:Line(start, rEnd, color)
	end
end

function FindPath(self)
	local playerPosition = Vision.hkvVec3(0,0,0)
	local myPosition = self:GetPosition()
	local distance = 0
	
	if LookForPlayer(self) then
		--get the this and the player's position
		playerPosition = G.player:GetPosition()
		
		--get the distance to the player
		distance = myPosition:getDistanceTo(playerPosition)
	else
		playerPosition = self.lastPlayerLocation

		--get the distance to the player's last location 
		distance = myPosition:getDistanceTo(playerPosition)
	end
	
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
			self.pathProgress = self.pathProgress + self.dt * self.chaseSpeed

			if self.pathProgress > self.pathLength then
				self.pathProgress = self.pathLength
			end
			
			local point = AI:GetPointOnPath(self.path, self.pathProgress)
			-- self:SetPosition(point)
			--[#todo] fix the bug that makes the character jump after x time(same as player script)
			local dir = point - myPosition
			dir:normalize()
			dir = dir * self.chaseSpeed
			self:SetMotionDeltaWorldSpace(dir)

			if self.pathProgress == self.pathLength then
				self.path = nil
			end
			
			--turn to face the player
			UpdateRotation(self)
		end
	end
end

--[[
returns true if the player is in range and unblocked, false otherwise
--]]
function LookForPlayer(self)
	--always cast a ray toward the player, if the angle > viewing angle ? false : True
	local rayStart = self:GetPosition()
	rayStart.z = rayStart.z  + self.eyeHeight
	
	local dir = (G.player:GetPosition() - self:GetPosition() )
	dir:normalize()
	local rayEnd = (dir * self.sightRange) + rayStart
	
	local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
	local hit, result = Physics.PerformRaycast(rayStart, rayEnd, iCollisionFilterInfo)
	
	local color = Vision.V_RGBA_BLUE
	Debug.Draw:Line(rayStart, rayEnd, color)
	
	if hit == true then
			-- check to see if a target was hit
			if result ~= nil and result["HitType"] == "Entity" then
				local hitObj = result["HitObject"]
				if hitObj:GetKey() == "Player" then
					local angle = self:GetObjDir():getAngleBetween(G.player:GetPosition() -  self:GetPosition() )
					if (angle < self.viewingAngle) and
					   (angle > -self.viewingAngle) then
					   self.lastPlayerLocation = hitObj:GetPosition()
						return true
					end
				end
			end
		end
	
	return false
end

function UpdateRotation(self)
	-- local step = self.rotSpeed * Timer:GetTimeDiff() * .01
	local dir = G.player:GetPosition() - self:GetPosition()
	self:SetDirection(dir)
end