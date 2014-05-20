-- new script file
function OnAfterSceneLoaded(self)
	-- self.rigidBody = self:GetComponentOfType("vHavokRigidBody")
	-- if self.rigidBody == nil then
		-- self.rigidBody = self:AddComponentOfType("vHavokRigidBody")
	-- end
	
	self.characterController = self:GetComponentOfType("vHavokCharacterController")
	if self.characterController == nil then
		self.characterController = self:AddComponentOfType("vHavokCharacterController")
	end
		
	--tuning variables
	self.moveSpeed = 50 --how fast this character should move when chasing the player	
	self.rotSpeed = 10
	self.maxAttackDistance = 90 --how close the NPC should get before attacking
	self.minAttackDistance = 75
	self.sightRange = 550 --how far the enemy can see a player
	self.viewingAngle = 90 --the angle that the NPC can see within
	
	self.numRays = 5
	self.attackAngle = 60
	self.attackRange = 70
	self.meleeDamage = 10
	
	self.eyeHeight = 50
	
	self.meleeCoolDown = 1.5
	self.timeToNextAttack = 0
	
	self.isAlive = true
	
	self.lastWaypoints = {}
	self.maxPrevPoints = 3
	
	self.Die = EnemyDeath
end

function OnThink(self)
	if not G.gameOver and self.isAlive then
		self.dt = Timer:GetTimeDiff()

		if self.timeToNextAttack > 0 then
			self.timeToNextAttack = self.timeToNextAttack - Timer:GetTimeDiff()
		end

		if not G.gameOver and G.player ~= nil then
			if LookForPlayer(self) then
				FindPathToPlayer(self)
			else
				FindNextWaypoint(self)
			end
			
			-- FindPath(self)
			if self.path ~= nil then
				NavigatePath(self)
			end
			
			--debugging ray
			-- local color = Vision.V_RGBA_RED
			-- local start = self:GetPosition()
			-- local rEnd = (self:GetObjDir() * 100) + start
			-- Debug.Draw:Line(start, rEnd, color)
		end
		
		ShowViewAngle(self)
	end
end

function FindPathToPlayer(self)
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
	if G.player.isAlive then
		if  distance > self.maxAttackDistance then
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
		elseif distance < self.maxAttackDistance and distance > self.minAttackDistance then
			if self.timeToNextAttack <= 0 then
				self.timeToNextAttack = 0
				ClearPath(self)
				PerformMelee(self)
			end		
		else
			ClearPath(self)
		end
	end
end

function NavigatePath(self)
	if self.path then
		self.pathProgress = self.pathProgress + self.dt * self.moveSpeed

		if self.pathProgress > self.pathLength then
			self.pathProgress = self.pathLength
		end
		
		if self.pathProgress == self.pathLength then
			self.path = nil
			
			if LookForPlayer(self) then
				FindPathToPlayer(self)
			else
				FindNextWaypoint(self)
			end
		else
			local point = AI:GetPointOnPath(self.path, self.pathProgress)
			local dir = point - self:GetPosition()
			dir:normalize()
			
			--turn to face the player
			UpdateRotation(self, dir)
			dir = dir * self.moveSpeed * .1
			
			--test for crash when dir is wrong
			self:SetMotionDeltaWorldSpace(dir)
			-- self:SetPosition(point)
		end
	end
end

function ClearPath(self)
	self.path = nil
	self.pathProgress = 0
	self.pathLength = 0
end

--[[
returns true if the player is in range, unblocked, and within the view angle false otherwise
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
	--Debug.Draw:Line(rayStart, rayEnd, color)
	
	if hit == true then
		-- check to see if a target was hit
		if result ~= nil then
			-- Debug:PrintLine(""..result["HitType"] )
			if (result["HitType"] == "Unknown") then
				local angle = self:GetObjDir():getAngleBetween(G.player:GetPosition() -  self:GetPosition() )
				if (angle < self.viewingAngle) and
					(angle > -self.viewingAngle) then
					self.lastPlayerLocation = result["ImpactPoint"]
					return true
				end
			end
		end
	end
	
	return false
end

function FindNextWaypoint(self)
	if self.path == nil then
		local myPosition = self:GetPosition()
		local distance = math.huge
			
		local numWaypoints = table.getn(G.waypoints)
			
		if numWaypoints > 0 then
			local closestPoint = nil
			for i =1, numWaypoints, 1 do
				local waypoint = G.waypoints[i]
				local currentDist = myPosition:getDistanceTo(waypoint:GetPosition())
				
				local tableSize = table.getn(self.lastWaypoints)
				
				--terrible block of code, will fix later
				if tableSize == 0 then
					if currentDist < distance then
						closestPoint = waypoint
						distance = currentDist
					end
				else
					local notInList = true
					for i = 0, tableSize, 1 do
						local prevPoint = self.lastWaypoints[i]
						
						if waypoint == prevPoint then
							notInList = false
						end
					end
					
					if notInList and currentDist < distance then
						closestPoint = waypoint
						distance = currentDist
					end
				end
			end
				
			local numPoints = table.getn(self.lastWaypoints)
			if numPoints > self.maxPrevPoints then
				table.remove(self.lastWaypoints, 1)
			end
			
			-- table.insert(self.lastWaypoints, closestPoint)
			self.lastWaypoints[#self.lastWaypoints + 1] = closestPoint
			
			local path = AI:FindPath(myPosition, closestPoint:GetPosition(), 20)
			if path ~= nil then
				local numPoints = table.getn(path)
				local endPoint = path[numPoints]
				self.path = path
				self.pathProgress = 0
				self.pathLength = AI:GetPathLength(path)
			end
		end
	end
end

function PerformMelee(self)
	CheckForAttackHit(self)
	StartCoolDown(self, self.meleeCoolDown)
end

function CheckForAttackHit(self)
	local myDir = self:GetObjDir() --(angle/self.numRays - 1)
	local myPos = self:GetPosition()
	myPos.z = myPos.z + 25
	
	
	for i = -math.floor(self.numRays / 2), math.floor(self.numRays / 2), 1 do
		--calculate the angle to cast a ray in relation to the current direction
		local currentAngle = ( (self.attackAngle / (self.numRays - 1) ) * i) 
		--convert the current angle to raidans
		currentAngle = currentAngle * (math.pi / 180)
		
		--rotate the forward direction based on the angle just calculated
		local newDir = RotateXY(myDir.x, myDir.y, myDir.z, currentAngle)
		
		local rayStart = myPos
		local rayEnd = myPos + (newDir * self.attackRange)
		
		--get the collision info
		local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
		local hit, result = Physics.PerformRaycast(rayStart, rayEnd, iCollisionFilterInfo)
		
		
		--Debug.Draw:Line(rayStart, rayEnd, Vision.V_RGBA_RED)
		
		if hit == true then
			--check to see if a target was hit
			if result ~= nil and result["HitType"] == "Unknown" then
				--hitObj.ModifyHealth(hitObj, -self.meleeDamage)
				G.player:ModifyHealth(-self.meleeDamage)
				--Debug:PrintLine("Player Hit!")
				break
			end
		end
	end
end

function EnemyDeath(self)
	--self:SetVisible(false)
	--deactivate character controller
end

function ShowViewAngle(self)
	-- local numRays = self.numRays
	local numRays = 3
	local myDir = self:GetObjDir()
	local myPos = self:GetPosition()
	myPos.z = myPos.z + 25
	
	for i = -math.floor(numRays / 2), math.floor(numRays / 2), 1 do
		--calculate the angle to cast a ray in relation to the current direction
		local currentAngle = ( (self.attackAngle / (numRays - 1) ) * i) 
		
		--convert the current angle to raidans
		currentAngle = currentAngle * (math.pi / 180)
		
		--rotate the forward direction based on the angle just calculated
		local newDir = RotateXY(myDir.x, myDir.y, myDir.z, currentAngle)
		
		local rayStart = myPos
		local rayEnd = myPos + (newDir * self.sightRange)
		
		Debug.Draw:Line(rayStart, rayEnd, Vision.V_RGBA_YELLOW)
	end
end

function UpdateRotation(self, dir)
	local step = self.rotSpeed * Timer:GetTimeDiff()
	local objDir = self:GetObjDir()
	local zHolder = objDir.z
	objDir:setInterpolate(objDir, dir, step)
	objDir.z = zHolder
	-- self:SetRotationDelta(objDir)
	self:SetDirection(objDir)
end

function StartCoolDown(self, coolDownTime)
	self.timeToNextAttack = coolDownTime
end

function RotateXY(x, y, z, angle)
	local _x = (x * math.cos(angle) ) - (y * math.sin(angle) )
	local _y = (x * math.sin(angle) ) + (y * math.cos(angle) )
	return Vision.hkvVec3(_x, _y, z)
end