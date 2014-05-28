--[[
Author: Denmark Gibbs
This script handles:
	-all input and control for the player
	-swtiching between animations
	-player attack, walk, run, etc
	-Player Pathfiding
	-all mouse control and input
	
This should be attached to the player.
The player must also have a behavior component attached
]]--
function OnAfterSceneLoaded(self)	
	--grab the behavior component
	self.behaviorComponent = self:GetComponentOfType("vHavokBehaviorComponent")
	if self.behaviorComponent == nil then
		self.behaviorComponent = self:AddComponentOfType("vHavokBehaviorComponent")
	end
	
	--create the input map
	self.map = Input:CreateMap("PlayerInputMap")
	
	--set the controls for the input map
	if G.isWindows then		
		--mouse movement controls:
		self.map:MapTrigger("CLICK", "MOUSE", "CT_MOUSE_LEFT_BUTTON")
		self.map:MapTrigger("X", "MOUSE", "CT_MOUSE_ABS_X")
		self.map:MapTrigger("Y", "MOUSE", "CT_MOUSE_ABS_Y")
		self.map:MapTrigger("RUN", "KEYBOARD", "CT_KB_LSHIFT")
		
		--Interaction controls:
		self.map:MapTrigger("MAGIC", "KEYBOARD", "CT_KB_F")
		self.map:MapTrigger("MELEE", "KEYBOARD", "CT_KB_SPACE", {once=true} )
		
		--GUI Display Controls
		self.map:MapTrigger("INVENTORY", "KEYBOARD", "CT_KB_1", {once=true}) --will show the display whilst holding 
	else
		--mouse movement controls:
		self.map:MapTrigger("CLICK", {0,0,G.w,G.h}, "CT_TOUCH_ANY")
		self.map:MapTrigger("X", {0,0,G.w,G.h}, "CT_TOUCH_ABS_X")
		self.map:MapTrigger("Y", {0,0,G.w,G.h}, "CT_TOUCH_ABS_Y")
		self.map:MapTrigger("RUN", G.yellowTable, "CT_TOUCH_ANY")

		--Interaction controls:
		self.map:MapTrigger("MAGIC", G.greenTable, "CT_TOUCH_ANY", {once=true} )
		self.map:MapTrigger("MELEE", G.redTable, "CT_TOUCH_ANY", {once=true} )
		
		--GUI Display Controls
		self.map:MapTrigger("INVENTORY", G.blueTable, "CT_TOUCH_ANY", {once=true} ) --will show the display whilst holding 
	end
	
	--establish a zero Vector
	self.zeroVector = Vision.hkvVec3(0,0,0)
	
	--setting up the tuning values:
	--Melee attack tunining
	self.meleeDamage = 10
	self.attackAngle = 60
	self.attackRange = 70
	
	--Magic attack tuning
	self.fireballDamage = 25
	self.maxSpellCount = 3
	self.spellCoolDown = .75 --how long the player must wait before doing another attack after a spell
	self.meleeCoolDown = .5 --how long the player must wait before doing another attack after a melee
	self.timeToNextAttack = 0 
	
	--locomotion values
	self.moveSpeed = 0
	self.walkSpeed = 2.5
	self.runSpeed = 5
	
	--variables for the mouse cursor
	self.mouseCursor = Game:CreateTexture("Textures/Cursor/RL_Cursor_Diffuse_Green_32.tga")
	self.mouseCursor = Game:CreateScreenMask(G.w / 2.0, G.h / 2.0, "Textures/Cursor/RL_Cursor_Diffuse_Green_32.tga")
	self.mouseCursor:SetBlending(Vision.BLEND_ALPHA)
	self.cursorSizeX, self.cursorSizeY  = self.mouseCursor:GetTextureSize()
	self.mouseCursor:SetZVal(5)
	--variables for keeping track of click location and times for particle
	self.clickParticlePath = "Particles\\RL_ClickParticle.xml"
	self.lastClickTime = 0
	self.clickCoolDown = .25
	self.goalRadius = 50 --how far the character should stop from a goal point
	
	--the player states, for switching between animations/actions
	self.states = {}
	self.states.walking = "walking"
	self.states.idle = "idle"
	self.states.attacking = "attacking"
	self.prevState = nil
	self.currentState = self.states.idle
	
	--bool to tell the game if the player is still alive
	self.isAlive = true
	
	--public functions to modify the attack power, and die
	self.ModifyPower = ModifyAttackPower
	self.Die = PlayerDeath
end

function OnBeforeSceneUnloaded(self)
	--delete the controller map
	Input:DestroyMap(self.map)
	self.map = nil
end

function OnThink(self)
	--this should only run if the level/game is not over, and the player is still alive
	if not G.gameOver  and self.isAlive then
		
		--cool down any active timers
		if self.timeToNextAttack > 0 then
			self.timeToNextAttack = self.timeToNextAttack - Timer:GetTimeDiff()
		end
		
		if self.lastClickTime > 0 then
			self.lastClickTime = self.lastClickTime - Timer:GetTimeDiff()
		end
		
		--cash the non-combat input controls
		local x = self.map:GetTrigger("X")
		local y = self.map:GetTrigger("Y")
		local run = self.map:GetTrigger("RUN") > 0
		local showInventory = self.map:GetTrigger("INVENTORY") > 0
		
		if self.currentState ~= self.states.attacking then
			--if the player is not currently attacking:
			--cache the combat controls
			local magic = self.map:GetTrigger("MAGIC") > 0
			local melee = self.map:GetTrigger("MELEE") > 0
			
			--set the move speed
			if run then
				self.moveSpeed = self.runSpeed
			else
				self.moveSpeed = self.walkSpeed
			end
			
			--the current attck cool down
			if self.timeToNextAttack <= 0 then
				self.timeToNextAttack = 0
				
				--if the timer is ready, and an attack trigger has been called, perform an attack
				if magic then
					CastSpell(self)
				elseif melee then
					PerformMelee(self)
				end
			end
		else
			--if the player is attacking:
			--local attackStopped = self.behaviorComponent:WasEventTriggered("AttackStop") -->behavior bug; fixed in 2014.1.0
			local attackStopped = not (self.timeToNextAttack > 0)
			
			--if the timer is less than or equal to 0, stop the attack
			if attackStopped then
				self.currentState = self.prevState
			end
		end
		
		--check to see if the player clicked the mouse
		if self.map:GetTrigger("CLICK") > 0 then
			--if the mouse was clicked, and the inventory is visble, check for an item selection
			local itemUsed = false
			if self.inventoryIsVisible then
				itemUsed = self.InventoryItemClicked(self, x, y)
			end
			
			--if an itema was not selected, set the new position to move to based on mouse position
			if not itemUsed then
				UpdateTargetPosition(self, x, y)
			end
		end
		
		--follow the path if one exists
		if self.path ~= nil then
			NavigatePath(self)
		end
		
		--update the mouse position on screen
		UpdateMouse(self, x, y)
		
		--show the player's stats
		ShowPlayerStats(self)
		
		--toggle the inventory
		if showInventory then
			self:ToggleInventory()
		end
		
		-- Debug:PrintLine(""..self.currentState) 
	else
		--when the game is over, or the player's health reaches zero, stop movment, and clear the AI Path
		self.mouseCursor:SetVisible(false)
		ClearPath(self)
		StopRotation(self)
		
		if self.currentState ~= self.states.idle then
			self.behaviorComponent:TriggerEvent("MoveStop")
			
			self.prevState = self.currentState
			self.currentState = self.states.idle
		end
	end
	
	--INSIDER ONLY, REMOVE BEFORE FINAL RELEASE
	--showing the difference between vectors and their representations
	--Debug.Draw:Line(self:GetPosition(), self:GetPosition() + (self:GetObjDir_Right() * 50), Vision.V_RGBA_GREEN)
	--Debug.Draw:Line(self:GetPosition(), self:GetPosition() + (self:GetObjDir() * 50), Vision.V_RGBA_RED)
end


function UpdateTargetPosition(self, mouseX, mouseY)
	--get a point on the navmesh based on the mouse position
	local goal = AI:PickPoint(mouseX, mouseY)
	
	if goal ~= nil then
		--spawn the particle if that point is not nil
		local particlePos =  Vision.hkvVec3(goal.x, goal.y, goal.z + .1)
		if self.lastClickTime <= 0 then
			Game:CreateEffect(particlePos, self.clickParticlePath)
			self.lastClickTime = self.clickCoolDown
		end
		
		--set the start point for the path
		local start = self:GetPosition()
		--create the path based ont the start and goal points
		local path = AI:FindPath(start, goal, 20.0, -1)
		
		if path ~= nil then
			--if a path exists:
			local numPoints = table.getn(path)
			local endPoint = path[numPoints]
			self.path = path
			self.pathProgress = 0
			self.pathLength = AI:GetPathLength(path)
			-- Debug:PrintLine("length: "..self.pathLength)
			self.goalPoint = goal
			self.lastPoint = start
			
			--[[
			To get the initial point, we won't use the start point here (a path progress of 0), 
			otherwise the character may walk in circles.
			Instead, we use a value further along the path to give the character plenty of room to turn and walk
			--]]
			self.nextPoint = AI:GetPointOnPath(self.path, 0.1)
		end
	end
end

function NavigatePath(self)
	--if the character is not currently moving, he should start now
	if self.currentState == self.states.idle then		
		self.behaviorComponent:TriggerEvent("MoveStart")
		
		--update the previous state
		self.prevState = self.currentState
		self.currentState = self.states.walking
	end
	
	--update the animation playback speed for walking/running based on moveSpeed variable 
	self.behaviorComponent:SetFloatVar("AnimMoveSpeed", self.moveSpeed)
	
	--check the distance to the next point
	local distanceToNext = self:GetPosition():getDistanceTo(self.nextPoint)
	
	--if the player is in range, recaculate the next point, and update the progress
	if distanceToNext <= self.goalRadius then
		self.pathProgress = self.pathProgress + (self.lastPoint:getDistanceTo(self.nextPoint) )
		self.lastPoint = self.nextPoint
		self.nextPoint = AI:GetPointOnPath(self.path, self.pathProgress)
		
		if self.nextPoint ~= nil then
			RotateToTarget(self, self.nextPoint)
		end
	end
	
	--if the end of the path has been reached, reset the variables
	if self.pathProgress >= self.pathLength then
		self.behaviorComponent:TriggerEvent("MoveStop")
		self.behaviorComponent:SetFloatVar("RotationSpeed", 0)
		self.prevState = self.currentState
		self.currentState = self.states.idle
		StopRotation(self)
		ClearPath(self)
	end
end

function UpdateMouse(self, xPos, yPos)
	--clamp the mouse x position to the screen space
	if xPos > G.w - self.cursorSizeX then
		xPos = G.w - self.cursorSizeX
	end
	
	--clamp the mouse y position to the screen space
	if yPos > G.h - self.cursorSizeY then
		yPos = G.h - self.cursorSizeY 
	end
	
	--set the last x position
	if xPos ~= 0 then
		self.lastX = xPos
	end
	
	--set the last y position
	if yPos ~= 0 then
		self.lastY = yPos
	end
	
	--set the cursor's position on screen
	self.mouseCursor:SetPos(self.lastX, self.lastY)
end

function RotateToTarget(self, target)
	--establish a deadZone
	local deadZone = 25
	
	----------------------------------------------------------------
	--[[ 
	IMPORTANT NOTE:
	--the forward direction was obtained this was because the object was exported facing the wrong direction
	normally, you would just use self:GetObjDir() to get the forward direction
	--]]
	local myDir = -self:GetObjDir_Right()
	local leftDir = self:GetObjDir()
	----------------------------------------------------------------
	
	--cache the variables to be used to determine which way the player should turn
	local myPos = self:GetPosition()
	local sign = 1 
	local targetDir = (target - myPos):getNormalized()
	local angle = myDir:getAngleBetween(targetDir)
	
	--get the sign of the angle between the current direction and the target direction
	if leftDir:dot(targetDir) < 0 then
		sign = -1
	end
	
	--cache the absolute value of the angle between the two directions
	local absAngle = math.abs(angle)
	
	--if the angle is greater than the deadzone, rotate the player, otherwise stop rotating
	if absAngle > deadZone then
		if myDir:dot(targetDir) > 0 then
			self.behaviorComponent:SetFloatVar("RotationSpeed", sign * angle)
		else
			self.behaviorComponent:SetFloatVar("RotationSpeed", sign * 360)
		end
	else
		StopRotation(self)
	end	
end

--actions that are performed each time a melee attack is executed
function PerformMelee(self)
	--begin the attack animation
	self.behaviorComponent:TriggerEvent("AttackStart")
	
	--set the state to attacking
	self.prevState = self.currentState
	self.currentState = self.states.attacking
	
	--check to see if the attack hits and do damage
	CheckForAttackHit(self)
	
	--start the timer to the next attack
	StartCoolDown(self, self.meleeCoolDown)
end


--[[
This function checks for an attack hit by casting a series of rays within a specified angle.
If any one of those rays hit an enemy, the loop is broken and damage is done to the enemy
--]]
function CheckForAttackHit(self)
	self.numRays = 5
	local myDir = -self:GetObjDir_Right() --(angle/self.numRays - 1)
	local myPos = self:GetPosition()
	myPos.z = myPos.z + 25
	
	for i = -math.floor(self.numRays / 2), math.floor(self.numRays / 2), 1 do
		--calculate the angle to cast a ray in relation to the current direction
		local currentAngle = ( (self.attackAngle / (self.numRays - 1) ) * i) 
		--convert the current angle to raidans
		currentAngle = currentAngle * (math.pi / 180)
		
		--rotate the forward direction based on the angle just calculated
		local newDir = RotateXY(myDir.x, myDir.y, myDir.z, currentAngle)
		
		--establish the starting point for the ray
		local rayStart = myPos
		local rayEnd = myPos + (newDir * self.attackRange)
		
		--get the collision info
		local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
		local hit, result = Physics.PerformRaycast(rayStart, rayEnd, iCollisionFilterInfo)
		
		if hit == true then
			--check to see if a target was hit
			if result ~= nil and result["HitType"] == "Entity" then
				local hitObj = result["HitObject"]
				if hitObj:GetKey() == "Enemy" then
					hitObj.ModifyHealth(hitObj, -self.meleeDamage)
					break
				end
			end
		end
	end
end

function CastSpell(self)
	--stop any current player rotation
	StopRotation(self)
	
	if self.numSpellsInPlay < self.maxSpellCount then
		if self.currentMana - self.fireballManaCost >= 0 then
			--set the direction to cast the spell
			local myDir = -self:GetObjDir_Right()
			
			--create the fireball spell
			self.CreateFireball(self, myDir)
			
			--update the current mana
			self:ModifyMana(-self.fireballManaCost)
			
			--start the cool down timer
			StartCoolDown(self, self.spellCoolDown)
		end
	end
end

--actions to complete when the player's health reaches zero
function PlayerDeath(self)
	--end the game when the player dies
	G.gameOver = true
	local manager = Game:GetEntity("LevelManager")
	G.Lose(manager)
end

--function for resetting the player's AI path
function ClearPath(self)
	self.lastPoint = nil
	self.nextPoint = nil
	self.path = nil
end

--stops the rotation of the player
function StopRotation(self)
	self:ResetRotationDelta()
	self.behaviorComponent:SetFloatVar("RotationSpeed", 0)
end

--Begins the attack cool down after a spell or melee
function StartCoolDown(self, coolDownTime)
	self.timeToNextAttack = coolDownTime
end

--HUD for the player's health, mana, and gem count
function ShowPlayerStats(self)
	Debug:PrintAt(G.w * (3 / 4), G.fontSize, "Health: "..self.currentHealth.."/"..self.maxHealth, Vision.V_RGBA_RED, G.fontPath)
	Debug:PrintAt(G.w * (3 / 4), G.fontSize * 2, "  Mana: ".. self.currentMana .."/"..self.maxMana, Vision.V_RGBA_BLUE, G.fontPath)
	Debug:PrintAt(G.w / 10, G.fontSize, "Gems: "..self.gemsCollected .. "/".. G.gemGoal, Vision.V_RGBA_GREEN, G.fontPath)
end

--function for increasing/decreasing the player's attack power
function ModifyAttackPower(self, amount)
	self.meleeDamage = self.meleeDamage + amount
	self.fireballDamage =  self.fireballDamage + amount
end

--function to be used by the attack, rotates a vector about the z axis
function RotateXY(x, y, z, angle)
	local _x = (x * math.cos(angle) ) - (y * math.sin(angle) )
	local _y = (x * math.sin(angle) ) + (y * math.cos(angle) )
	return Vision.hkvVec3(_x, _y, z)
end