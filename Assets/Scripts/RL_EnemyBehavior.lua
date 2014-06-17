--[[
Author: Denmark Gibbs
This script handles:
	--all enemy AI and pathfinding logic
	--enemy death
	--enemy movement
	
This should be attached to the enemy/enemies.
The enemy must have a character controller attached
]]--

--callback function that is invoked automatically after the scene has been loaded but before the first Think Loop
function OnAfterSceneLoaded(self)
	--enable debug drawing for the HUD and view cone for enemies
	Debug:Enable(true)
	
	--get the character controller attached to this entity or attach one if one was not found
	self.characterController = self:GetComponentOfType("vHavokCharacterController")
	if self.characterController == nil then
		self.characterController = self:AddComponentOfType("vHavokCharacterController")
	end
	
	--set this character to be alive
	self.isAlive = true
	
	--set the time to next attack. when this is zero, the character can attack
	self.timeToNextAttack = 0
	
	--table for storing previous waypoints so the character doesn't bounce back and forth between them
	self.lastWaypoints = {}
	self.maxPrevPoints = 3 --how many previous waypoints to store
	
	--store the location of the sounds that this character will use
	self.deathSoundPath = "Sounds/RL_CharacterDeath.wav"
	self.meleeHitSoundPath = "Sounds/RL_SwordHitSound.wav"
	
	--the particle that will spawn when the enemy dies
	self.deathParticlePath = "Particles\\RL_EnemyDeathFlame.xml"
	
	--function to be called by the Damageable script when the enemy's health reaches 0
	self.Die = EnemyDeath
end

--This function allows variables to be tuned in the components window
function OnExpose(self)
	--tuning variables
	self.moveSpeed = 50 --how fast this character should move when chasing the player	
	self.rotSpeed = 10 --how fast the character should rotate
	self.maxAttackDistance = 90 --how close the NPC should get before attacking
	self.minAttackDistance = 0	--how close the enemy can be when attacking
	self.sightRange = 550 --how far the enemy can see a player
	self.viewingAngle = 120 --the angle that the NPC can see within
	
	--variables to be used for attacking
	self.numRays = 5  --number of rays to cast when checking for an attack hit
	self.attackAngle = 60  --the angle the character attacks within 
	self.attackRange = 70  --how far away an attack can hit within the attackAngle
	self.meleeDamage = 5  --how much damage is done if an attack hits
	
	--how high from the ground the enemy will cast a ray to check for the player
	self.eyeHeight = 50
	
	--the radius Havok AI should search for available points 
	self.aiSearchRadius = 20
	--how long to cool down after an attack
	self.meleeCoolDown = 1.5
	
	--the height from which attacks will be done
	self.attackHeight = 25
end

--callback function invoked automatically once per frame
--anything the character should be doing very often should be done here
function OnThink(self)
	if not G.gameOver and self.isAlive then
		--get the delta time since last frame
		self.dt = Timer:GetTimeDiff()
	
		--update the attack cool down timer if it is not zero
		if self.timeToNextAttack > 0 then
			self.timeToNextAttack = self.timeToNextAttack - self.dt
		end
		
		--if there is a player, look for it
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
			
			-- navigate the found path to either the player or next waypoint
			if self.path ~= nil then
				NavigatePath(self)
			end
		end
		
		--if the debugging mode is enabled, Draw the debug info
		if G.isAiDebugInfoOn then
			--Show the enemy's FOV using debug lines
			ShowViewAngle(self)
			
			--show the enemy paths
			ShowAIDebugInfo(self)
		end
	end
end

--[[
This function finds a path to the player if the player is in sight.
--]]
function FindPathToPlayer(self)
	--create variables for the player's position, this current position, and distance. 
	--these may change, but need to be initialized first
	local playerPosition = Vision.hkvVec3(0,0,0)
	local myPosition = self:GetPosition()
	local distance = math.huge --set the distance to something far out of attack range, in this case math.huge
	
	--if the player is still in view, go to that position, go to the last known place otherwise
	if LookForPlayer(self) then
		--if the player is still in sight, cache that location
		playerPosition = G.player:GetPosition()		
	else
		--if the player is no longer in sight, cache the previous location
		playerPosition = self.lastPlayerLocation
	end
	
	--get the distance to the player's position (or last position if it isn't seen)
	distance = myPosition:getDistanceTo(playerPosition)

	--find a path to the player if it is still alive
	if G.player.isAlive then
		--check to see if this character is in attack range
		if  (distance > self.maxAttackDistance) or (distance < self.minAttackDistance) then
			--if out of range, find path and move closer
			local path = AI:FindPath(myPosition, playerPosition, self.aiSearchRadius)
			
			--if a path exists, store the information needed for navigation
			if path ~= nil then
				--the number of points along the path
				local numPoints = table.getn(path)
				--the last point on the path
				local endPoint = path[numPoints]
				--store the path
				self.path = path
				--this variable will store how far along the path this character has traveled
				self.pathProgress = 0
				--store the total length of the path
				self.pathLength = AI:GetPathLength(path)
			end
		elseif distance < self.maxAttackDistance and distance > self.minAttackDistance then
			--if in range, attack if timer is less than or equal to zero
			if self.timeToNextAttack <= 0 then
				--reset the timer back to zero
				self.timeToNextAttack = 0
				--remove the current path
				ClearPath(self)
				--perform an attack
				PerformMelee(self)
			end		
		else
			--if all else fails, clear the path and start over
			ClearPath(self)
		end
	end
end


--[[
This function locates the closest waypoint int the scene, and finds a path to it.
--]]
function FindNextWaypoint(self)
	if self.path == nil then
		--cache the current position
		local myPosition = self:GetPosition()
		
		--set the distance to infinity, so that the first waypoint is added automatically
		local distance = math.huge
		
		--get the total number of waypoints
		local numWaypoints = table.getn(G.waypoints)
		
		--find the number of previous waypoints	
		local numPrevWaypoints = table.getn(self.lastWaypoints)
		
		--if there are waypoints in the scene, begin finding the closest one
		if numWaypoints > 0 then
			local closestPoint = nil
			
			--iterate through the points to find the closest one
			for i =1, numWaypoints, 1 do
				--store the current waypoint
				local waypoint = G.waypoints[i]
				
				--get the distance to the current waypoint
				local currentDist = myPosition:getDistanceTo(waypoint:GetPosition())
				
				--if there are no previous points, go to the closest one
				if numPrevWaypoints == 0 then
					--make sure that the distance to the next point is less than the distance previously found
					if currentDist < distance then
						--if this distance is smaller, save the waypoint and the distance to it
						closestPoint = waypoint
						distance = currentDist
					end
				else
					--assume the current waypoint has not already been visited recently
					local notInList = true
					--check to see if the current waypoint has already been visited by looping through the previous waypoints
					for i = 0, numPrevWaypoints, 1 do
						--store the currently selected previous point
						local prevPoint = self.lastWaypoints[i]
						
						--if current waypoint is the same as a previous one, 
						--then it has already been visited, and should be ignored
						if waypoint == prevPoint then
							notInList = false
						end
					end
					
					--if the waypoint is not in the table, and it is closer than the current closest,
					--set this as the closest point and update the distance
					if notInList and currentDist < distance then
						--save the waypoint and the distance to it
						closestPoint = waypoint
						distance = currentDist
					end
				end
			end
			
			--if the table of previous points is full, remove the oldest point
			local numPoints = table.getn(self.lastWaypoints)
			if numPoints > self.maxPrevPoints then
				table.remove(self.lastWaypoints, 1)
			end
			
			--insert the current waypoint to the list of previous points
			self.lastWaypoints[#self.lastWaypoints + 1] = closestPoint
			
			--find the path to the selected point
			local path = AI:FindPath(myPosition, closestPoint:GetPosition(), self.aiSearchRadius)
			
			--if a path was found, get information needed to navigate the path
			if path ~= nil then
				--the number of points along the path
				local numPoints = table.getn(path)
				--the last point on the path
				local endPoint = path[numPoints]
				--store the path
				self.path = path
				--this variable will store how far along the path this character has traveled
				self.pathProgress = 0
				--store the total length of the path
				self.pathLength = AI:GetPathLength(path)
			end
		end
	end
end


--[[
This function takes the path that was found and moves this character along it. 
This function also handles rotating this character in the direction of the path
--]]
function NavigatePath(self)
	--this should only do something if the path is not nil
	if self.path ~= nil then
		--update the progress along the path
		self.pathProgress = self.pathProgress + self.dt * self.moveSpeed
		
		--keep this character from going past the end of the path
		if self.pathProgress > self.pathLength then
			self.pathProgress = self.pathLength
		end
		
		--clear the path if the end has been reached
		if self.pathProgress == self.pathLength then
			--remove the current path
			self.path = nil
			
			--check again to see if the player is in sight
			if LookForPlayer(self) then
				--if the player is in sight, find a path to it
				FindPathToPlayer(self)
			else
				--if the player is not in sight, move to the next waypoint
				FindNextWaypoint(self)
			end
		else
			--if the end of the path has not been reached...
			
			--find and normalize the directtion to the current point on the path
			local point = AI:GetPointOnPath(self.path, self.pathProgress)
			--get the direction to the next point, this will be the direction this character should face
			local dir = point - self:GetPosition()
			dir:normalize()
			
			--call the function to turn and face the player
			UpdateRotation(self, dir)
			
			--here we multiply the direction times the move speed to get the move vector
			dir = dir * self.moveSpeed * .1  --> this needs fixing
			
			--move the character in the direction of the next point
			self:SetMotionDeltaWorldSpace(dir)
		end
	end
end

--[[
This function returns true if the player is in range, unblocked, and within the view angle 
otherwise it returns false.
It does this by casting a ray toward the player, if the angle > viewing angle then the player is in sight
--]]
function LookForPlayer(self)
	--set the start position of the ray to this character's position
	local rayStart = self:GetPosition()
	--move the ray up in space so that it's about where a character's eyes would be
	rayStart.z = rayStart.z  + self.eyeHeight
	
	--calculate the direction to cast the ray 
	local dir = (G.player:GetPosition() - self:GetPosition() )
	--normalize the direction vector we just found
	dir:normalize()
	
	--the ray ends at the sight range of the enemy
	local rayEnd = (dir * self.sightRange) + rayStart
	
	--set up the collsion info for the ray; this is consistent for almost all rays this project uses
	local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
	--Perform the raycast
	local hit, result = Physics.PerformRaycast(rayStart, rayEnd, iCollisionFilterInfo)
	
	-- check to see if a target was hit
	if hit == true then
		-- if something was hit, get iformation about it
		if result ~= nil then
			--in this case, we want to check if the hit type is "Unknown"
			--in 2014.1 this should check for "Entity" and check to see if the key is "Player"
			if (result["HitType"] == "Unknown") then
				--check to see if the player is in the enemies sight angle
				local angle = self:GetObjDir():getAngleBetween(G.player:GetPosition() -  self:GetPosition() )
				if (angle < self.viewingAngle / 2 ) and
					(angle > -self.viewingAngle / 2) then
					--if the player is in veiw of the enemy, set it's location to be the last known location
					--we do this because the player may move out of sight, but we still want to go to that position
					self.lastPlayerLocation = result["ImpactPoint"]
					--since the player was sighted, return true
					return true
				end
			end
		end
	end
	
	--if the player was not sighted, the return false
	return false
end
--[[
This function clears the Ai Path. It is used when attacking, or when the enemy has reached the end of its current path
--]]
function ClearPath(self)
	--set the current path to nil
	self.path = nil
	--reset the progress along the path
	self.pathProgress = 0
	--reset the path length to zero
	self.pathLength = 0
end

--[[
This function is called whenever this character performs a melee attack
--]]
function PerformMelee(self)
	--call the function that checks for an attack hit
	CheckForAttackHit(self)	
	--start the cooldown timer
	StartCoolDown(self, self.meleeCoolDown)
end

--[[
This function checks for an attack hit by casting a series of rays within a specified angle.
If any one of those rays hit the player, the loop is exited and damage is done
--]]
function CheckForAttackHit(self)
	--get this character's current direction and position
	local myDir = self:GetObjDir() 
	local myPos = self:GetPosition()
	--adjust the position so that the ray is not on the ground
	myPos.z = myPos.z + self.attackHeight
	
	--[[
	In order to check for an attack, we will cast rays equal to the specified number (self.numRays) 
	within the specified angle (self.attackAngle).
	This loop will calculate the direction in which each ray should be cast, and checks for a hit.
	If the ray hits nothing, the loop will continue until all rays have been cast. 
	--]]
	for i = -math.floor(self.numRays / 2), math.floor(self.numRays / 2), 1 do
		--calculate the angle to cast a ray in relation to the current direction
		local currentAngle = ( (self.attackAngle / (self.numRays - 1) ) * i) 
		
		--convert the current angle to raidans
		currentAngle = currentAngle * (math.pi / 180)
		
		--get the direction to cast a ray based on the angle we just calculated
		local newDir = RotateXY(myDir.x, myDir.y, myDir.z, currentAngle)
		
		--the ray should start at this character's current position
		local rayStart = myPos
		--the ray should end at a point that is equal to the attack range in distance away, 
		--and in the direction that we just calculated
		local rayEnd = myPos + (newDir * self.attackRange)
		
		--get the collision info
		local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
		--perform the raycast
		local hit, result = Physics.PerformRaycast(rayStart, rayEnd, iCollisionFilterInfo)
		
		--check to see if the ray hit
		if hit == true then
			--note that the Character Controller from HAT cannot be detected by raycast, this is fixed in a later release
			--this is why we check for "Unknown" instead of "Entity" here.
			if result ~= nil and result["HitType"] == "Unknown" then
				--call the appropriate function to deal damage to the player
				G.player:ModifyHealth(-self.meleeDamage)
				
				--play the hit sound if it exists
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

--[[
This function is to be called when the enemy's health reaches zero.
It simply hides the enemy and disables it's charater controller so that it no longer moves and cannot be hit
--]]
function EnemyDeath(self)
	--play the death sound if it exists
	local deathSound = Fmod:CreateSound(self:GetPosition(), self.deathSoundPath, false)
	if deathSound ~= nil then
		deathSound:Play()
	end
	
	--spawn the death particle at the current location
	Game:CreateEffect(self:GetPosition(), self.deathParticlePath)
	
	--hide the enemy
	self:SetVisible(false)
	--deactivate character controller
	self.characterController:SetEnabled(false)
end

--[[
This function displays the FOV of the enemy using debug lines, so the player knows what the enemy can 'see'
--]]
function ShowViewAngle(self)
	-- local numRays = self.numRays
	local numRays = self.numRays
	--store the current direction and position
	local myDir = self:GetObjDir()
	local myPos = self:GetPosition()
	--adjust the eye height
	myPos.z = myPos.z + self.eyeHeight
	
	--here we will loop through each ray in the same way we do for the attack.
	--we will cast the rays within the angle and draw them, rather than check for hits
	for i = -math.floor(numRays / 2), math.floor(numRays / 2), 1 do
		--calculate the angle to cast a ray in relation to the current direction
		local currentAngle = ( (self.attackAngle / (numRays - 1) ) * i) 
		
		--convert the current angle to raidans
		currentAngle = currentAngle * (math.pi / 180)
		
		--get the direction to cast a ray based on the angle we just calculated
		local newDir = RotateXY(myDir.x, myDir.y, myDir.z, currentAngle)
		
		--the ray will start at the current position
		local rayStart = myPos
		--the ray will end at a distance equal to the sight range 
		local rayEnd = myPos + (newDir * self.sightRange)
		
		--Draw the ray to represent what the enemy can 'see'
		Debug.Draw:Line(rayStart, rayEnd, Vision.V_RGBA_YELLOW)
	end
end

--[[
This function interpolates this character's direction toward the desired direction. 
--]]
function UpdateRotation(self, dir)
	--calculate the rotation speed
	local step = self.rotSpeed * Timer:GetTimeDiff()
	--store the object's current direction
	local objDir = self:GetObjDir()
	--store the current z value so that it only rotates in the xy plane
	local zHolder = objDir.z
	--get the interpolation between the two directions
	objDir:setInterpolate(objDir, dir, step)
	--reset the z value to the stored value
	objDir.z = zHolder
	--set the current direction to the calculated direction
	self:SetDirection(objDir)
end

--[[
This function begins the attack cool down by setting the timeToNextAttack to the cool down time.
Since it is not zero, timeToNextAttack will decrement in the OnThink callback.
--]]
function StartCoolDown(self, coolDownTime)
	self.timeToNextAttack = coolDownTime
end

--[[
This is a utilty function to be used by the ShowViewAngle and CheckForAttackHit functions. 
It rotates a vector about the z axis and returns the the rotated vector. 
--]]
function RotateXY(x, y, z, angle)
	local _x = (x * math.cos(angle) ) - (y * math.sin(angle) )
	local _y = (x * math.sin(angle) ) + (y * math.cos(angle) )
	return Vision.hkvVec3(_x, _y, z)
end

--[[
This function will show the Ai information for the current player including:
-the path
-the player radius
--]]
function ShowAIDebugInfo(self)
	--we'll add height buffer to all of the debug drawing so that they won't z fight with the ground
	local heightOffset = Vision.hkvVec3(0,0,15)
	
	--whenever the path is not nil, we want to draw the path that was calculated
	if self.path ~= nil then
		--get the number of points in the path
		local numPoints = table.getn(self.path)
		
		--loop through each point in the path
		for i = 1, numPoints - 1, 1 do
			--store the current point and the next point
			local currentPoint = self.path[i]
			local nextPoint = self.path[i+1]
			
			--draw a line from the current point to the next point
			Debug.Draw:Line(currentPoint + heightOffset, nextPoint + heightOffset, Vision.V_RGBA_RED)
		end
	end
end