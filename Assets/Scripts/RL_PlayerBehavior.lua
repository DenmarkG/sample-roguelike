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
	
	--this section is used for drawing the AI/debug information. 
	--when self.isAiDebugInfoOn is true, the player radius and path will be drawn on screen
	self.playerDebugCircle = Game:GetPath("PlayersCircle")
	if self.playerDebugCircle ~= nil then
		--this is the original info for the path, which came directly from the editor
		--we need this info since the size of the path will change later
		self.originalRadius = 200
		self.originalTangentDistance = 110.3568
		
		--make sure the path is closed to avoid odd shapes
		if not self.playerDebugCircle:IsClosed() then
			self.playerDebugCircle:SetClosed(true)
		end
		
		--call the function to set the new positions of the pathNodes based on the
		--ai search radius declared in the OnExpose function
		SetPathNodesToPlayerRadius(self) 
	end
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
	
	--the radius Havok AI should search for available points. 
	--Smaller numbers will result in bumping and sliding around corners
	self.aiSearchRadius = 45
	
	--the number of rays to cast when checking for an attack hit
	self.numRays = 5
	
	--the height at which we'll check for an attck hit
	self.attackHeight = 25
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
				--if an item was clicked then this will evaluate to true
				itemUsed = self.InventoryItemClicked(self, x, y)
			end
			
			--if an itema was not selected, set the new position to move to based on mouse position
			if not itemUsed then
				UpdateTargetPosition(self, x, y)
			end
		end
		
		--call the function to follow the path if one exists
		if self.path ~= nil then
			NavigatePath(self)
		end
		
		--if the player has a rotation target, then it should rotate in that direction.  
		if self.rotationTarget ~= nil then
			RotateToTarget(self, self.rotationTarget)
		end
		
		--update the mouse position on screen
		UpdateMouse(self, x, y)
		
		--show the player's health, mana, and gems collected
		ShowPlayerStats(self)
		
		--toggle the inventory if the inventory button was pressed
		if showInventory then
			self:ToggleInventory()
		end
		
		-- show 'Help' if the help button was pressed
		if help then
			ShowControls(self)
		end
		
		
		if G.isAiDebugInfoOn then
			ShowAIDebugInfo(self)
		end
	else
		--when the game is over, or the player's health reaches zero, stop movment, and clear the AI Path
		
		--hide the cursor
		self.mouseCursor:SetVisible(false)
		--clear the player's path so that it stops moving
		ClearPath(self)
		--stop any of the player's rotation
		StopRotation(self)
		
		--make sure the player goes into the idle state
		if self.currentState ~= self.states.idle then
			--stop the walk animation
			self.behaviorComponent:TriggerEvent("MoveStop")
			
			--save the current state as the previous state
			self.prevState = self.currentState
			--set the current state to idle
			self.currentState = self.states.idle
		end
	end
end

--[[
This function takes the mouse's current position, and uses it to find a path for the player.  
It is called when the mouse is clicked, but only if an inventory item was not selected.
--]]
function UpdateTargetPosition(self, mouseX, mouseY)
	--get a point on the navmesh based on the mouse position
	local goal = AI:PickPoint(mouseX, mouseY)
	
	--if a valid goal point was found, then we should find a path to the player
	if goal ~= nil then
		--spawn the particle at the clicked location
		local particlePos =  Vision.hkvVec3(goal.x, goal.y, goal.z + .1)
		--
		if self.lastClickTime <= 0 then
			Game:CreateEffect(particlePos, self.clickParticlePath)
			self.lastClickTime = self.clickCoolDown
		end
		
		--set the start point for the path as the player's current position
		local start = self:GetPosition()
		--create the path based ont the start and goal points
		local path = AI:FindPath(start, goal, self.aiSearchRadius)
		
		--if a path was found, get and store information about the path
		if path ~= nil then
			self.numPoints = table.getn(path)
			self.endPoint = path[numPoints]
			--store the path
			self.path = path
			--this variable will store how far along the path this character has traveled
			self.pathProgress = 0
			--store the total length of the path
			self.pathLength = AI:GetPathLength(path)
			--store the goal point of the path
			self.goalPoint = goal
			--store the start point of the path
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

--[[
This function moves the character along the path that was found, and stops the player when the end of the path is reached.
This also assigns a rotation target for the player to turn toward while walking.
--]]
function NavigatePath(self)
	--if the character is not currently in a moving state, it should start now
	--note that if the character is currently attacking, it will start walking AFTER the attack has finished
	if self.currentState == self.states.idle then	
		--start the walk animation
		self.behaviorComponent:TriggerEvent("MoveStart")
		
		--update the previous state to be the current state
		self.prevState = self.currentState
		--set the current state to the walking state.
		self.currentState = self.states.walking
	end
	
	--update the animation playback speed for walking/running based on moveSpeed variable 
	self.behaviorComponent:SetFloatVar("AnimMoveSpeed", self.moveSpeed)
	
	--check the distance to the next point
	local distanceToNext = self:GetPosition():getDistanceTo(self.nextPoint)
	
	--if the next point is within the goal radius, find the next point, and update the path progress
	if distanceToNext <= self.goalRadius then
		--add the distance traveled since the last point to the overall distance traveled
		self.pathProgress = self.pathProgress + (self.lastPoint:getDistanceTo(self.nextPoint) )
		--set the current point as the previous point
		self.lastPoint = self.nextPoint
		--find the new point to travel to 
		self.nextPoint = AI:GetPointOnPath(self.path, self.pathProgress)
		--set the rotation target as the next point on the path so the player can rotate toward it
		self.rotationTarget = self.nextPoint
	end
	
	--if the end of the path has been reached, stop movement and set state to idle
	if self.pathProgress >= self.pathLength then
		--stop the walk animation
		self.behaviorComponent:TriggerEvent("MoveStop")
		--reset the rotation speed to zero
		self.behaviorComponent:SetFloatVar("RotationSpeed", 0)
		
		--set the current and previous states
		if self.currentState ~= self.states.attacking then
			--if th player is not attacking, set the previous state to the current state
			self.prevState = self.currentState
			--then set the current state to idle
			self.currentState = self.states.idle
		else
			--if the player is attacking, set the previous state to idle.
			--we do this so the player stops moving after the attack
			self.prevState = self.states.idle
		end
		
		--if the player reaches the end, but is not aimed properly, keep rotating
		--this way, the player can still rotate fully when the path's end is close to the start
		if self.aimedAtTarget == false then
			self.rotationTarget = self.goalPoint
		end
		
		--call the function to reset the path
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
		--NOTE: the value is very high here so that the player turns smoothly and quickly. 
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
		--if the angle is less than the deadzone, then we can stop the rotation
		self.aimedAtTarget = true
		StopRotation(self)
	end
end

--[[
This function is used to stop the rotation of the player
--]]
function StopRotation(self)
	--remove any rotation delta on the character controller
	self:ResetRotationDelta()
	--set the variable that controls rotation back to zero
	self.behaviorComponent:SetFloatVar("RotationSpeed", 0)
	--clear the rotation target
	self.rotationTarget = nil
end

--[[
This funcion is used to set the mouse cursor's position on screen.
It also keeps the mouse from being drawn offscreen by clamping the x and y position values
--]]
function UpdateMouse(self, xPos, yPos)
	--clamp the mouse x position to the screen space in relation to the cursor's size
	if xPos > G.w - self.cursorSizeX then
		xPos = G.w - self.cursorSizeX
	end
	
	--clamp the mouse y position to the screen space in relation to the cursor's size
	if yPos > G.h - self.cursorSizeY then
		yPos = G.h - self.cursorSizeY 
	end
	
	--[[
	Here we store the last x and y position's since the player may not always be touching the
	screen on a device, but we still want to draw the cursor's last location.
	--]]
	--store the last x position
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

--[[
This function performs actions that are performed each time a melee attack is executed
--]]
function PerformMelee(self)
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
	--get this character's current direction and position
	local myDir = -self:GetObjDir_Right() --(angle/self.numRays - 1)
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
			--check to see if the object hiw was an entity
			if result ~= nil and result["HitType"] == "Entity" then
				--get the information about the HitObject
				local hitObj = result["HitObject"]
				--Check that the Key of the hit object was "Enemy"
				if hitObj:GetKey() == "Enemy" then
					--get and play the hit sound if it is not nil
					local hitSound = Fmod:CreateSound(result[ImpactPoint], self.swordHitSoundPath, false)
					if hitSound ~= nil then
						hitSound:Play()
					end
					
					--call the funtion to deal damage to the enmy
					hitObj.ModifyHealth(hitObj, -self.meleeDamage)
					
					--break this loop to avoid hitting the same enemy twice
					break
				end
			end
		end
	end
end

--[[
This function simply checks to see if a a spell can be cast, and, if so, calls the appropriate function
from the SpellManager script to create and update the spell (in this case they are all fireballs)
--]]
function CastSpell(self)
	--only cast a new spell if the max number of spells in play has not been reached
	if self.numSpellsInPlay < self.maxSpellCount then
		--check to see if the player has enough mana available to cast a new spell
		if self.currentMana - self.fireballManaCost >= 0 then
			--set the direction to cast the spell; in this case, the player's forward direction
			local myDir = self:GetObjDir()
			
			--call the function to create the fireball spell
			self.CreateFireball(self, myDir)
			
			--call the function to update the current mana
			self:ModifyMana(-self.fireballManaCost)
			
			--start the cool down timer
			StartCoolDown(self, self.spellCoolDown)
		end
	end
end

--[[
This function is to be called when the player's health reaches zero.
It hides the character, plays a sound, and changes the appropriate booleans to end the game
--]]
function PlayerDeath(self)
	--find and play the death sound if it exists
	local deathSound = Fmod:CreateSound(self:GetPosition(), self.deathSoundPath, false)
	if deathSound ~= nil then
		deathSound:Play()
	end
	
	--hide the character
	self:SetVisible(false)
	
	--end the game when the player dies
	G.gameOver = true
	--call the function to lose the level
	local manager = Game:GetEntity("LevelManager")
end

--[[
This funciton creates the HUD for the player's health, mana, and gem count using Debug:PrintAt
--]]
function ShowPlayerStats(self)
	--the line for player health
	Debug:PrintAt(G.w * (3 / 4), G.fontSize, "Health: "..self.currentHealth.."/"..self.maxHealth, Vision.V_RGBA_RED, G.fontPath)
	--the line for player mana
	Debug:PrintAt(G.w * (3 / 4), G.fontSize * 2, "  Mana: ".. self.currentMana .."/"..self.maxMana, Vision.V_RGBA_PURPLE, G.fontPath)
	--the line for player gem count
	Debug:PrintAt(G.w / 10, G.fontSize, "Gems: "..self.gemsCollected .. "/".. G.gemGoal, Vision.V_RGBA_YELLOW, G.fontPath)
end

--[[
This function is called whenever the help button is pressed.  It shows the controls for the game using Debug:PrintAt.
Since the controls vary by platform, this does a check to determine which set of controls to display.  
--]]
function ShowControls(self)
	if G.isWindows then
		--Show the Windows controls
		Debug:PrintAt(10, 64, "Move: LEFT CLICK", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 96, "Run: LEFT SHIFT", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 128, "Melee: SPACEBAR", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 160, "Magic: F", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 192, "Inventory: 1", Vision.V_RGBA_WHITE, G.fontPath)
	else
		--Show the Touch controls
		Debug:PrintAt(10, 64, "Move: TAP", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 96, "Run: YELLOW", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 128, "Melee: Red", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 160, "Magic: GREEN", Vision.V_RGBA_WHITE, G.fontPath)
		Debug:PrintAt(10, 192, "Inventory: Blue", Vision.V_RGBA_WHITE, G.fontPath)
	end
end

--[[
This function is used for resetting the player's AI path. 
It is called when the player should stop following the current path
--]]
function ClearPath(self)
	--set the number of points back to 0
	self.numPoints = 0
	--set the end point back to nil
	self.endPoint = nil
	--set the previous point to nil
	self.lastPoint = nil
	--set the next point to nil
	self.nextPoint = nil
	--set the path to nil
	self.path = nil
end

--[[
This function begins the attack cool down by setting the timeToNextAttack to the cool down time.
Since it is not zero, timeToNextAttack will decrement in the OnThink callback.
--]]
function StartCoolDown(self, coolDownTime)
	self.timeToNextAttack = coolDownTime
end

--[[
This function is used for increasing/decreasing the player's attack power.
Currently it is only used by the Power Potion to increase the attack power. 
--]]
function ModifyAttackPower(self, amount)
	self.meleeDamage = self.meleeDamage + amount
	self.fireballDamage =  self.fireballDamage + amount
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
This is another Utility funciton that caluclates the new tangents, once the nodes of the path have been moved.
***Note*** that in the scene, the bezier handles are ~110 units away from the player, and the radius is 200 units.
we will use this information to find position of the new tangents
--]]
function CalculateNewTangents(self)
	self.tangentDistance = (self.originalTangentDistance *  self.aiSearchRadius) / self.originalRadius
end

--[[
This is utility function for getting the path nodes for drawing the path with the proper radius.
This function will find the nodes as children of the path, then assign each to a varible to be used later
--]]
function SetPathNodesToPlayerRadius(self)
	--cache the player's current position
	local currentPosition = self:GetPosition()
	
	--get the distance of the new tangents
	CalculateNewTangents(self)
	
	--[[
	In this section, we get each node by its key, then store it to a member variable.
	also, we will offset the node by the search radius so that the path accurately reflects the radius
	once this is done we must set the tangents to the proper position, so that the circle maintains its relative shape
	Note that the in/out tangents follow a counter-clockwise pattern
	--]]
	
	local count = 0
	
	--the positive X direction
	self.node_PosX = self.playerDebugCircle:GetPathNode("Node_PosX")
	if self.node_PosX ~= nil then
		self.node_PosX:SetPosition(Vision.hkvVec3(currentPosition.x + self.aiSearchRadius, currentPosition.y, currentPosition.z) )
		self.node_PosX:SetControlVertices(Vision.hkvVec3(currentPosition.x + self.aiSearchRadius, currentPosition.y - self.tangentDistance, currentPosition.z), 
											Vision.hkvVec3(currentPosition.x + self.aiSearchRadius, currentPosition.y + self.tangentDistance, currentPosition.z) )
	end	
	
	--the positive Y direction
	self.node_PosY = self.playerDebugCircle:GetPathNode("Node_PosY")
	if self.node_PosY ~= nil then
		self.node_PosY:SetPosition(Vision.hkvVec3(currentPosition.x, currentPosition.y + self.aiSearchRadius, currentPosition.z) )
		self.node_PosY:SetControlVertices(Vision.hkvVec3(currentPosition.x + self.tangentDistance, currentPosition.y + self.aiSearchRadius, currentPosition.z), 
											Vision.hkvVec3(currentPosition.x - self.tangentDistance, currentPosition.y + self.aiSearchRadius, currentPosition.z) )
	end
	
	--the negative X direcion
	self.node_NegX = self.playerDebugCircle:GetPathNode("Node_NegX")
		if self.node_NegX ~= nil then
		self.node_NegX:SetPosition(Vision.hkvVec3(currentPosition.x - self.aiSearchRadius, currentPosition.y, currentPosition.z) )
		self.node_NegX:SetControlVertices(Vision.hkvVec3(currentPosition.x - self.aiSearchRadius, currentPosition.y + self.tangentDistance, currentPosition.z), 
											Vision.hkvVec3(currentPosition.x - self.aiSearchRadius, currentPosition.y - self.tangentDistance, currentPosition.z) )
	end
	
	--the negative Y direcion
	self.node_NegY = self.playerDebugCircle:GetPathNode("Node_NegY")
	if self.node_NegY ~= nil then
		self.node_NegY:SetPosition(Vision.hkvVec3(currentPosition.x, currentPosition.y - self.aiSearchRadius, currentPosition.z) )
		self.node_NegY:SetControlVertices(Vision.hkvVec3(currentPosition.x - self.tangentDistance, currentPosition.y - self.aiSearchRadius, currentPosition.z), 
											Vision.hkvVec3(currentPosition.x + self.tangentDistance, currentPosition.y - self.aiSearchRadius, currentPosition.z) )
	end
	
	--[[
	Here we find the fifth node that gets created at runtime.
	We can't search by key since the new node that gets created is a duplicate of the first.  Instead we get it by index,
	since we know that it is added to the end of the list of children of the path entity.
	--]]
	local nodeIndex = self.playerDebugCircle:GetPathNodeCount() - 1
	local fifthNode = self.playerDebugCircle:GetPathNode(nodeIndex)
		
	--Now, we set it's tangents to be the same as the first, since it will be located in the same position
	fifthNode:SetPosition(Vision.hkvVec3(currentPosition.x, currentPosition.y - self.aiSearchRadius, currentPosition.z) )
	fifthNode:SetControlVertices(Vision.hkvVec3(currentPosition.x - self.tangentDistance, currentPosition.y - self.aiSearchRadius, currentPosition.z), 
										Vision.hkvVec3(currentPosition.x + self.tangentDistance, currentPosition.y - self.aiSearchRadius, currentPosition.z) )
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
		--loop through each point in the path
		for i = 1, self.numPoints - 1, 1 do
			--store the current point and the next point
			local currentPoint = self.path[i]
			local nextPoint = self.path[i+1]
			
			--draw a line from the current point to the next point
			Debug.Draw:Line(currentPoint + heightOffset, nextPoint + heightOffset, Vision.V_RGBA_GREEN)
		end
	end
	
	--draw the path represents the player radius
	if self.playerDebugCircle ~= nil then
		Renderer.Draw:Path(self.playerDebugCircle, Vision.V_RGBA_PURPLE)
	end
end