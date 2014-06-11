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

--callback function that is called after the scene has been loaded but before the first Think Loop
function OnAfterSceneLoaded(self)	
	--grab the behavior component or create one if it is nil
	self.behaviorComponent = self:GetComponentOfType("vHavokBehaviorComponent")
	if self.behaviorComponent == nil then
		self.behaviorComponent = self:AddComponentOfType("vHavokBehaviorComponent")
	end
	
	--create the input map
	self.map = Input:CreateMap("PlayerInputMap")
	
	--set the controls for the input map and assign controls for both Windows and Touch Devices
	if G.isWindows then		
		--mouse movement controls:
		self.map:MapTrigger("CLICK", "MOUSE", "CT_MOUSE_LEFT_BUTTON")
		self.map:MapTrigger("X", "MOUSE", "CT_MOUSE_ABS_X")
		self.map:MapTrigger("Y", "MOUSE", "CT_MOUSE_ABS_Y")
		self.map:MapTrigger("RUN", "KEYBOARD", "CT_KB_LSHIFT")
		self.map:MapTrigger("HELP", "KEYBOARD", "CT_KB_H")
		
		--Interaction controls:
		self.map:MapTrigger("MAGIC", "KEYBOARD", "CT_KB_F")
		self.map:MapTrigger("MELEE", "KEYBOARD", "CT_KB_SPACE", {once=true} )
		
		--GUI Display Controls
		self.map:MapTrigger("INVENTORY", "KEYBOARD", "CT_KB_1", {once=true} ) --will show the inventory display whilst holding 
	else
		--mouse movement controls:
		self.map:MapTrigger("CLICK", {0,0,G.w,G.h}, "CT_TOUCH_ANY")
		self.map:MapTrigger("X", {0,0,G.w,G.h}, "CT_TOUCH_ABS_X")
		self.map:MapTrigger("Y", {0,0,G.w,G.h}, "CT_TOUCH_ABS_Y")
		self.map:MapTrigger("RUN", G.yellowTable, "CT_TOUCH_ANY")

		--Interaction controls:
		self.map:MapTrigger("MAGIC", G.greenTable, "CT_TOUCH_ANY", {once=true} )
		self.map:MapTrigger("MELEE", G.redTable, "CT_TOUCH_ANY", {once=true} )
		self.map:MapTrigger("HELP", G.helpTable, "CT_TOUCH_ANY") --will show the help menu whilst holding 
		
		--GUI Display Controls
		self.map:MapTrigger("INVENTORY", G.blueTable, "CT_TOUCH_ANY", {once=true} ) --will show the display whilst holding 
	end
	
	--establish a zero Vector
	self.zeroVector = Vision.hkvVec3(0,0,0)
	
	self.moveSpeed = 0  --variable that will tell the walk animation how fast to play
	
	--variable to be used for attack cool downs
	self.timeToNextAttack = 0 
	
	--setting the sound paths
	self.deathSoundPath = "Sounds/RL_CharacterDeath.wav"
	self.swordHitSoundPath = "Sounds/RL_SwordHitSound.wav"
	
	--create the screen mask to show the mouse cursor
	self.mouseCursor = Game:CreateScreenMask(G.w / 2.0, G.h / 2.0, "Textures/Cursor/RL_Cursor_Diffuse_Green_32.tga")
	--set the blending of the cursor to alpha (the visibility of the cursor will be based on the alpha channel of the texutre)
	self.mouseCursor:SetBlending(Vision.BLEND_ALPHA)
	--store the vertical and horizontal size of the texture
	self.cursorSizeX, self.cursorSizeY  = self.mouseCursor:GetTextureSize()
	--set the z value of the cursor so it draws on top of all other elements on scren
	self.mouseCursor:SetZVal(5)
	
	--store the location of the click particle
	self.clickParticlePath = "Particles\\RL_ClickParticle.xml"
	
	--the next few variables will be used to keep track of mouse clicks, and allow for a brief cooldown time between clicks
	self.lastClickTime = 0
	self.clickCoolDown = .25
	
	--store how far the character should stop from a goal point
	self.goalRadius = 75 
	
	--the player states, for switching between animations/actions
	self.states = {}
	self.states.walking = "walking"
	self.states.idle = "idle"
	self.states.attacking = "attacking"
	self.prevState = nil
	self.currentState = self.states.idle
	
	--bool to tell the game if the player is still alive
	self.isAlive = true
	
	self.aimedAtTarget = true --tells if the player is properly aimed at the next/target position
	
	--public functions to modify the attack power, and die
	self.ModifyPower = ModifyAttackPower
	self.Die = PlayerDeath
end

--the OnExpose function allows variables to be changed in the component panel
function OnExpose(self)
	--setting up the tuning values:
	--Melee attack tunining
	self.meleeDamage = 25 -- how much damage the player does when an attack lands
	self.attackAngle = 60 -- the angle in which to check for an attack
	self.attackRange = 70 -- how far from the player a melee attack can land

	--Magic attack tuning
	self.fireballDamage = 25 --how much damage a fireball will do when it lands
	self.maxSpellCount = 3 --how many fireballs can be in play at one time
	self.spellCoolDown = 1 --how long the player must wait before doing another attack after a spell
	self.meleeCoolDown = 1 --how long the player must wait before doing another attack after a melee
	
	--locomotion values
	self.walkSpeed = 2.5 --how fast the walk animation should play when walking
	self.runSpeed = 5 --how fast the walk animation should play when running
end

--this callback is called automatically before the scene is unloaded
function OnBeforeSceneUnloaded(self)
	--delete the controller map
	Input:DestroyMap(self.map)
	--set the controller map to nil
	self.map = nil
end

--callback function called automatically once per frame
function OnThink(self)
	--this should only run if the level/game is not over, and the player is still alive
	if not G.gameOver  and self.isAlive then
		
		--first, cool down any active timers
		--cool down the attack timer
		if self.timeToNextAttack > 0 then
			self.timeToNextAttack = self.timeToNextAttack - Timer:GetTimeDiff()
		end
		
		--cool down the click timer
		if self.lastClickTime > 0 then
			self.lastClickTime = self.lastClickTime - Timer:GetTimeDiff()
		end
		
		--cache the non-combat input
		local x = self.map:GetTrigger("X")
		local y = self.map:GetTrigger("Y")
		local run = self.map:GetTrigger("RUN") > 0
		local showInventory = self.map:GetTrigger("INVENTORY") > 0
		local help = self.map:GetTrigger("HELP") > 0
		
		--set the move speed based on if the player is running or not
		if run then
			--if running, the moveSpeed should be the runSpeed
			self.moveSpeed = self.runSpeed
		else
			--if not running, the moveSpeed should be the walkSpeed
			self.moveSpeed = self.walkSpeed
		end
		
		--check to see if the player is attacking
		if self.currentState ~= self.states.attacking then
			--if the player is not currently attacking:
			--cache the combat input
			local magic = self.map:GetTrigger("MAGIC") > 0
			local melee = self.map:GetTrigger("MELEE") > 0
			
			--the current attck cool down
			if self.timeToNextAttack <= 0 then
				self.timeToNextAttack = 0
				
				--if the timer is ready, and an attack trigger has been called, perform an attack
				--only one can be done at a time, and the spell takes precedence
				if magic then
					--if magic button was pressed, call the function to cast a spell
					CastSpell(self)
				elseif melee then
					--if the melee button was pressed then call the function to perform a melee attack
					PerformMelee(self)
				end
			end		
		else
			--if the player is attacking:
			--check to see if the attack has stopped
			local attackStopped = not (self.timeToNextAttack > 0)
			
			
			--if the timer is less than or equal to 0, stop the attack
			if attackStopped then
				--set the player's current state based on whether the path is nil or not.
				if self.path == nil then
					--if the path is nil, return to the idle state and stop walking
					self.currentState = self.states.idle
					self.behaviorComponent:TriggerEvent("MoveStop")
				else
					--if the path is not nil, set the current state to walking and begin walking
					self.currentState = self.states.walking
					self.behaviorComponent:TriggerEvent("MoveStart")
				end
				
				--set the attack as the previous state
				self.prevState = self.states.attacking
			end
		end
		
		--check to see if the player clicked the mouse
		if self.map:GetTrigger("CLICK") > 0 then
			--if the mouse was clicked, and the inventory is visble, check for an item selection
			--assume an item has not been used
			local itemUsed = false
			--if the inventory is visible, then check to see if an item was clicked
			if self.inventoryIsVisible then
				itemUsed = self.InventoryItemClicked(self, x, y)
			end
			
			--if an itema was not selected, set the new position to move to based on mouse position
			if not itemUsed then
				UpdateTargetPosition(self, x, y)
			end
		end
------------------------------------------------------------------------------		
		--follow the path if one exists
		if self.path ~= nil then
			NavigatePath(self)
		end
		
		if self.rotationTarget ~= nil then
			RotateToTarget(self, self.rotationTarget)
		end
		
		--update the mouse position on screen
		UpdateMouse(self, x, y)
		
		--show the player's stats
		ShowPlayerStats(self)
		
		--toggle the inventory
		if showInventory then
			self:ToggleInventory()
		end
		
		-- show 'Help'
		if help then
			ShowControls(self)
		end
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
	
	Debug:PrintLine(""..self.currentState)
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
	-- --if the character is not currently moving, he should start now
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
		self.rotationTarget = self.nextPoint
	end
	
	--if the end of the path has been reached, reset the variables
	if self.pathProgress >= self.pathLength then
		self.behaviorComponent:TriggerEvent("MoveStop")
		self.behaviorComponent:SetFloatVar("RotationSpeed", 0)
		
		if self.currentState == self.states.walking then
			self.prevState = self.currentState
			self.currentState = self.states.idle
		elseif self.currentState == "attacking" then
			self.prevState = self.states.idle
		end
		
		--if the player reaches the end, but is not aimed properly, keep rotating
		if self.aimedAtTarget == false then
			self.rotationTarget = self.goalPoint
		end
		
		--remove the references to the path
		ClearPath(self)
	end
end

--[[
This function should be called every time the character needs to change direction.
This directly affects the RotateCharacterModifier from HAT.  Since the character may have to
rotate a lot in a short distance, the value is set very high (720 deg/sec) when this happens. 
--]]
function RotateToTarget(self, target)
	--establish a deadZone
	local deadZone = 5
	
	--remove the z component since we only want the calculate the angle in 2 dimensions
	target.z = 0
	
	--here we cache the direction of the player
	local myDir = self:GetObjDir()
	
	--note: in vision, the function GetObjDir_Right actually gets the left vector (positive Y)
	local leftDir = self:GetObjDir_Right()
	
	--cache the variables to be used to determine which way the player should turn
	local myPos = self:GetPosition()
	myPos.z = 0 --again, remove the z component
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
		self.aimedAtTarget = false
		
		--the speed of roation is based on the angle; greater angle, greater speed
		if myDir:dot(targetDir) > 0 then
			if absAngle < 45 then
				self.behaviorComponent:SetFloatVar("RotationSpeed", sign * 180 )
			elseif absAngle < 90 then
				self.behaviorComponent:SetFloatVar("RotationSpeed", sign * 360 )
			elseif absAngle < 180 then
				self.behaviorComponent:SetFloatVar("RotationSpeed", sign * 540 )
			end
		else
			self.behaviorComponent:SetFloatVar("RotationSpeed", sign * 720)
		end
	else
		self.aimedAtTarget = true
		StopRotation(self)
	end
end

--stops the rotation of the player
function StopRotation(self)
	self:ResetRotationDelta()
	self.behaviorComponent:SetFloatVar("RotationSpeed", 0)
	self.rotationTarget = nil
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
	if self.lastY ~= nil and self.lastX ~= nil then
		self.mouseCursor:SetPos(self.lastX, self.lastY)
	end
end

--actions that are performed each time a melee attack is executed
function PerformMelee(self)
	--clear the path, stop movement and rotation
	--ClearPath(self)
	--StopRotation(self)
	
	--set the previous state to the current state
	self.prevState = self.currentState
	
	--begin the attack animation
	self.behaviorComponent:TriggerEvent("AttackStart")
	
	--set the state to attacking
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
					--play the hit sound
					local hitSound = Fmod:CreateSound(result[ImpactPoint], self.swordHitSoundPath, false)
					if hitSound ~= nil then
						hitSound:Play()
					end
					
					--damage the enmy
					hitObj.ModifyHealth(hitObj, -self.meleeDamage)
					
					--break this loop to avoid hitting the same enemy twice
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
			local myDir = self:GetObjDir()
			
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
	--play the death sound
	local deathSound = Fmod:CreateSound(self:GetPosition(), self.deathSoundPath, false)
	if deathSound ~= nil then
		deathSound:Play()
	end
	
	--hide the character
	self:SetVisible(false)
	
	--end the game when the player dies
	G.gameOver = true
	local manager = Game:GetEntity("LevelManager")
	G.Lose(manager)
end

--HUD for the player's health, mana, and gem count
function ShowPlayerStats(self)
	Debug:PrintAt(G.w * (3 / 4), G.fontSize, "Health: "..self.currentHealth.."/"..self.maxHealth, Vision.V_RGBA_RED, G.fontPath)
	Debug:PrintAt(G.w * (3 / 4), G.fontSize * 2, "  Mana: ".. self.currentMana .."/"..self.maxMana, Vision.V_RGBA_BLUE, G.fontPath)
	Debug:PrintAt(G.w / 10, G.fontSize, "Gems: "..self.gemsCollected .. "/".. G.gemGoal, Vision.V_RGBA_GREEN, G.fontPath)
end

function ShowControls(self)
	if G.isWindows then
		Debug:PrintAt(10, 64, "Move: LEFT CLICK", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 96, "Run: LEFT SHIFT", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 128, "Melee: SPACEBAR", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 160, "Magic: F", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 182, "Inventory: 1", Vision.V_RGBA_WHITE, G.fontPath)
	else
		Debug:PrintAt(10, 64, "Move: TAP", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 96, "Run: YELLOW", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 128, "Melee: Red", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 160, "Magic: GREEN", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 182, "Inventory: Blue", Vision.V_RGBA_WHITE, G.fontPath)
	end
end

--function for resetting the player's AI path
function ClearPath(self)
	self.lastPoint = nil
	self.nextPoint = nil
	self.path = nil
end

--Begins the attack cool down after a spell or melee
function StartCoolDown(self, coolDownTime)
	self.timeToNextAttack = coolDownTime
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