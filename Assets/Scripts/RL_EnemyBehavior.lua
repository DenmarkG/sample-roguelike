--[[
Author: Denmark Gibbs
This script handles:
	--all enemy AI and pathfinding logic
	--enemy death
	--enemy movement
	
This should be attached to the enemy/enemies.
The enemy must have a character controller attached
]]--

function OnAfterSceneLoaded(self)
	Debug:Enable(true)
	
	--get the character controller attached to this entity
	self.characterController = self:GetComponentOfType("vHavokCharacterController")
	if self.characterController == nil then
		self.characterController = self:AddComponentOfType("vHavokCharacterController")
	end
	
	self.isAlive = true
	self.timeToNextAttack = 0
	
	--variable for keeping track of previous waypoints so the enemy doesn't bounce back and forth
	self.lastWaypoints = {}
	self.maxPrevPoints = 3
	
	--set up the sounds
	self.deathSoundPath = "Sounds/RL_CharacterDeath.wav"
	self.meleeHitSoundPath = "Sounds/RL_SwordHitSound.wav"
	
	--the particle that will spawn when the enemy dies
	self.deathParticlePath = "Particles\\RL_EnemyDeathFlame.xml"
	
	--function to be called by other scripts when the enemy's health reaches 0
	self.Die = EnemyDeath
end

function OnExpose(self)
	--tuning variables
	self.moveSpeed = 50 --how fast this character should move when chasing the player	
	self.rotSpeed = 10
	self.maxAttackDistance = 90 --how close the NPC should get before attacking
	self.minAttackDistance = 0
	self.sightRange = 550 --how far the enemy can see a player
	self.viewingAngle = 120 --the angle that the NPC can see within
	
	--variables to be used for attacking
	self.numRays = 5
	self.attackAngle = 60
	self.attackRange = 70
	self.meleeDamage = 5
	
	--how high from the ground the enemy will cast a ray to check for the player
	self.eyeHeight = 50
	
	--how long to cool down after an attack
	self.meleeCoolDown = 1.5
end

function OnThink(self)
	if not G.gameOver and self.isAlive then
		--get the delta time since last frame
		self.dt = Timer:GetTimeDiff()
	
		--update the attack cool down timer
		if self.timeToNextAttack > 0 then
			self.timeToNextAttack = self.timeToNextAttack - self.dt
		end
		
		--
		if G.player ~= nil then
			--check to see if the player can be seen 
			LookForPlayer(self)
			if LookForPlayer(self) then
				--if so, navigate to that location
				FindPathToPlayer(self)
			else
				--if not, navigate to the next waypoint
				FindNextWaypoint(self)
			end
			
			-- FindPath(self)
			if self.path ~= nil then
				NavigatePath(self)
			end
		end
		
		--Show the enemy's FOV
		ShowViewAngle(self)
	end
end

function FindPathToPlayer(self)
	--create variables for the player's position, this current position, and distance. these will change
	local playerPosition = Vision.hkvVec3(0,0,0)
	local myPosition = self:GetPosition()
	local distance = math.huge
	
	--if the player is still in view, go to that position, go to the last known place otherwise
	if LookForPlayer(self) then
		playerPosition = G.player:GetPosition()		
	else
		playerPosition = self.lastPlayerLocation
	end
	
	--get the distance to the player's last position
	distance = myPosition:getDistanceTo(playerPosition)

	--finding a path
	if G.player.isAlive then
		if  (distance > self.maxAttackDistance) or (distance < self.minAttackDistance) then
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
			--if in range, attack if possible
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

function FindNextWaypoint(self)
	if self.path == nil then
		--cache the current position
		local myPosition = self:GetPosition()
		
		--set the distance to infinity, so that the first waypoint is added
		local distance = math.huge
		
		--get the total number of waypoints
		local numWaypoints = table.getn(G.waypoints)
		
		--find the number of previous waypoints	
		local tableSize = table.getn(self.lastWaypoints)
			
		if numWaypoints > 0 then
			local closestPoint = nil
			
			--iterate through the points to find the closest one
			for i =1, numWaypoints, 1 do
				--store the current waypoint
				local waypoint = G.waypoints[i]
				
				--get the distance to the current waypoint
				local currentDist = myPosition:getDistanceTo(waypoint:GetPosition())
				
				if tableSize == 0 then
					--if there are no previous points, go to the closest one
					if currentDist < distance then
						closestPoint = waypoint
						distance = currentDist
					end
				else
					local notInList = true
					--check to see if the current waypoint has already been visited
					for i = 0, tableSize, 1 do
						local prevPoint = self.lastWaypoints[i]
						
						if waypoint == prevPoint then
							notInList = false
						end
					end
					
					--if the waypoint is not in the table, and it is closer than the current closest,
					--set this as the closest point and update the distance
					if notInList and currentDist < distance then
						closestPoint = waypoint
						distance = currentDist
					end
				end
			end
			
			--if the table is full, remove the oldest point
			local numPoints = table.getn(self.lastWaypoints)
			if numPoints > self.maxPrevPoints then
				table.remove(self.lastWaypoints, 1)
			end
			
			--insert the current waypoint to the list of previous points
			self.lastWaypoints[#self.lastWaypoints + 1] = closestPoint
			
			--find the path to the selected point
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

function NavigatePath(self)
	if self.path then
		--update the progress along the path
		self.pathProgress = self.pathProgress + self.dt * self.moveSpeed
		
		--don't go past the end of the path
		if self.pathProgress > self.pathLength then
			self.pathProgress = self.pathLength
		end
		
		--clear the path if the end has been reached
		if self.pathProgress == self.pathLength then
			self.path = nil
			
			--check again to see if the player is in sight
			if LookForPlayer(self) then
				FindPathToPlayer(self)
			else
				FindNextWaypoint(self)
			end
		else
			--find and normalize the directtion to the current point on the path
			local point = AI:GetPointOnPath(self.path, self.pathProgress)
			local dir = point - self:GetPosition()
			dir:normalize()
			
			--turn to face the player
			UpdateRotation(self, dir)
			dir = dir * self.moveSpeed * .1
			
			--test for crash when dir is wrong
			self:SetMotionDeltaWorldSpace(dir)
		end
	end
end

--[[
returns true if the player is in range, unblocked, and within the view angle 
otherwise returns false
--]]
function LookForPlayer(self)
	--cast a ray toward the player, if the angle > viewing angle then the player is in sight
	local rayStart = self:GetPosition()
	rayStart.z = rayStart.z  + self.eyeHeight
	
	local dir = (G.player:GetPosition() - self:GetPosition() )
	dir:normalize()
	
	--the ray ends at the sight range of the enemy
	local rayEnd = (dir * self.sightRange) + rayStart
	
	local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
	local hit, result = Physics.PerformRaycast(rayStart, rayEnd, iCollisionFilterInfo)
	
	-- local color = Vision.V_RGBA_BLUE
	-- Debug.Draw:Line(rayStart, rayEnd, color)
	
	if hit == true then
		-- check to see if a target was hit
		if result ~= nil then
			-- Debug:PrintLine(""..result["HitType"] )
			if (result["HitType"] == "Unknown") then
				--check to see if the player is in the enemies sight angle
				local angle = self:GetObjDir():getAngleBetween(G.player:GetPosition() -  self:GetPosition() )
				if (angle < self.viewingAngle / 2 ) and
					(angle > -self.viewingAngle / 2) then
					self.lastPlayerLocation = result["ImpactPoint"]
					return true
				end
			end
		end
	end
	
	return false
end

--Clears the Ai Path
function ClearPath(self)
	self.path = nil
	self.pathProgress = 0
	self.pathLength = 0
end

--called when performing a melee attack
function PerformMelee(self)
	CheckForAttackHit(self)	
	StartCoolDown(self, self.meleeCoolDown)
end

--[[
This function checks for an attack hit by casting a series of rays within a specified angle.
If any one of those rays hit the player, the loop is broken and damage is done
--]]
function CheckForAttackHit(self)
	-- Debug:PrintLine("Attack Started")
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
		
		if hit == true then
			--check to see if a target was hit
			--note that the Character Controller from HAT cannot be detected by raycast, this is fixed in a later release
			if result ~= nil and result["HitType"] == "Unknown" then
				--damage the player
				G.player:ModifyHealth(-self.meleeDamage)
				
				--play the hit sound
				local hitSound = Fmod:CreateSound(result[ImpactPoint], self.meleeHitSoundPath, false)
				if hitSound ~= nil then
					hitSound:Play()
				end
				
				--break the loop to avoid hitting the player twice
				break
			end
		end
	end
end

--function to be called when the enemy's health reaches zero
function EnemyDeath(self)
	--play the death sound
	local deathSound = Fmod:CreateSound(self:GetPosition(), self.deathSoundPath, false)
	if deathSound ~= nil then
		deathSound:Play()
	end
	
	--play the death particle
	Game:CreateEffect(self:GetPosition(), self.deathParticlePath)
	
	--hide the enemy
	self:SetVisible(false)
	--deactivate character controller
	self.characterController:SetEnabled(false)
end

--displays the FOV of the enemy, so theplayer knows what the enemy can 'see'
function ShowViewAngle(self)
	-- local numRays = self.numRays
	local numRays = 7
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
		
		--Draw what the enemiy can "see"
		Debug.Draw:Line(rayStart, rayEnd, Vision.V_RGBA_YELLOW)
	end
end

--Roatates the enemy toward the desired direction
function UpdateRotation(self, dir)
	local step = self.rotSpeed * Timer:GetTimeDiff()
	local objDir = self:GetObjDir()
	local zHolder = objDir.z
	objDir:setInterpolate(objDir, dir, step)
	objDir.z = zHolder
	self:SetDirection(objDir)
end

--begins the attack cool down
function StartCoolDown(self, coolDownTime)
	self.timeToNextAttack = coolDownTime
end

--function to be used by the attack, rotates a vector about the z axis
function RotateXY(x, y, z, angle)
	local _x = (x * math.cos(angle) ) - (y * math.sin(angle) )
	local _y = (x * math.sin(angle) ) + (y * math.cos(angle) )
	return Vision.hkvVec3(_x, _y, z)
end