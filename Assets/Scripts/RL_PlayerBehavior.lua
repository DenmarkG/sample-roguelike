-- new script file
function OnAfterSceneLoaded(self)
	
	--grab the behavior component
	self.behaviorComponent = self:GetComponentOfType("vHavokBehaviorComponent")
	if self.behaviorComponent == nil then
		self.behaviorComponent = self:AddComponentOfType("vHavokBehaviorComponent")
	end
	
	-- self.characterController = self.behaviorComponent:GetComponentOfType("vHavokCharacterController")
	-- if self.characterController == nil then
		-- self.characterController = self:AddComponentOfType("vHavokCharacterController")
	-- end
	
	--self.characterController:SetCollisionInfo(1,0,0,0)
	
	--create the input map
	self.map = Input:CreateMap("PlayerInputMap")
	
	--set the controls for the input map
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
	
	--establish a zero Vector
	self.zeroVector = Vision.hkvVec3(0,0,0)
	
	--set up the tuning values
	self.moveSpeed = 0
	self.walkSpeed = 2.5
	self.runSpeed = 5
	self.maxSpellCount = 3
	self.spellCoolDown = .75 --how long the player must wait before doing another attack after a spell
	self.meleeCoolDown = .5 --how long the player must wait before doing another attack after a melee
	self.timeToNextAttack = 0 
	
	self.attackAngle = 60
	self.attackRange = 70
	self.meleeDamage = 10
	
	self.invalidMouseCursor = Game:CreateTexture("Textures/Cursor/RL_Cursor_Diffuse_Red_32.tga")
	self.validMouseCursor = Game:CreateTexture("Textures/Cursor/RL_Cursor_Diffuse_Green_32.tga")
	
	self.mouseCursor = Game:CreateScreenMask(G.w / 2.0, G.h / 2.0, "Textures/Cursor/RL_Cursor_Diffuse_Red_32.tga")
	self.mouseCursor:SetBlending(Vision.BLEND_ALPHA)
	self.cursorSizeX, self.cursorSizeY  = self.mouseCursor:GetTextureSize()
	self.mouseCursor:SetZVal(5)
	
	self.goalRadius = 50 --how far the character should stop from a goal point
	
	self.states = {}
	self.states.walking = "walking"
	self.states.idle = "idle"
	self.states.attacking = "attacking"
	
	self.prevState = nil
	self.currentState = self.states.idle
	
	self.isAlive = true
end

function OnBeforeSceneUnloaded(self)
	--delete the controller map
	Input:DestroyMap(self.map)
	self.map = nil
end

function OnThink(self)
	-- for i = 1, table.getn(self.inventory), 1 do
		-- local item = self.inventory[i]
		-- Debug:PrintLine("item: " .. item.name)
	-- end
	
	if not G.gameOver  and self.isAlive then
	
		if self.timeToNextAttack > 0 then
			self.timeToNextAttack = self.timeToNextAttack - Timer:GetTimeDiff()
		end
		
		local x = self.map:GetTrigger("X")
		local y = self.map:GetTrigger("Y")
		
		local run = self.map:GetTrigger("RUN") > 0
		
		local showInventory = self.map:GetTrigger("INVENTORY") > 0
		
		if self.currentState ~= self.states.attacking then
			local magic = self.map:GetTrigger("MAGIC") > 0
			local melee = self.map:GetTrigger("MELEE") > 0
			
			if run then
				self.moveSpeed = self.runSpeed
			else
				self.moveSpeed = self.walkSpeed
			end
			
			if self.timeToNextAttack <= 0 then
				self.timeToNextAttack = 0
							
				if magic then
					CastSpell(self)
				elseif melee then
					PerformMelee(self)
				end
			end
		else
			--local attackStopped = self.behaviorComponent:WasEventTriggered("AttackStop") -->behavior bug
			local attackStopped = not (self.timeToNextAttack > 0)
			
			if attackStopped then
				-- Debug:PrintLine("AttackStopped!")
				self.currentState = self.prevState
			end
		end
		
		if self.map:GetTrigger("CLICK") > 0 then
			local itemUsed = false
			if self.inventoryIsVisible then
				itemUsed = self.InventoryItemClicked(self, x, y)
			end
			
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
	end
	
	--Debug.Draw:Line(self:GetPosition(), self:GetPosition() + (self:GetObjDir_Right() * 50), Vision.V_RGBA_GREEN)
	--Debug.Draw:Line(self:GetPosition(), self:GetPosition() + (self:GetObjDir() * 50), Vision.V_RGBA_RED)
end


function UpdateTargetPosition(self, mouseX, mouseY)
	local goal = AI:PickPoint(mouseX, mouseY)
	
	if goal ~= nil then
		local start = self:GetPosition()
		local path = AI:FindPath(start, goal, 20.0, -1)
		if path ~= nil then
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
	if self.currentState == self.states.idle then		
		self.behaviorComponent:TriggerEvent("MoveStart")
		
		self.prevState = self.currentState
		self.currentState = self.states.walking
	end
	
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
	
	--local myPos = self:GetPosition()
	--Debug.Draw:Line(myPos, self.nextPoint, Vision.V_RGBA_RED)
	
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
	--clamp the mouse to the screen space
	if xPos > G.w - self.cursorSizeX then
		xPos = G.w - self.cursorSizeX
	end
	
	if yPos > G.h - self.cursorSizeY then
		yPos = G.h - self.cursorSizeY 
	end
	
	self.mouseCursor:SetPos(xPos, yPos)
end

function RotateToTarget(self, target)
	local deadZone = 25
	
	--the forward direction was obtained this was because the object was exported facing the wrong direction
	--normally, you would just use self:GetObjDir() to get the forward direction
	local myDir = -self:GetObjDir_Right()
	local leftDir = self:GetObjDir()
	local myPos = self:GetPosition()
	local sign = 1 
	local targetDir = (target - myPos):getNormalized()
	local angle = myDir:getAngleBetween(targetDir) -- (90 * sign)
	
	if leftDir:dot(targetDir) < 0 then
		--Debug:PrintLine("I'm on happy side!")
		sign = -1
	end
	
	local absAngle = math.abs(angle)
	
	if absAngle > deadZone then
		if myDir:dot(targetDir) > 0 then
			self.behaviorComponent:SetFloatVar("RotationSpeed", sign * angle)
		else
			self.behaviorComponent:SetFloatVar("RotationSpeed", sign * 360)
		end
	else
		StopRotation(self)
	end	
	
	--Debug.Draw:Line(myPos, myPos + myDir * 150, Vision.V_RGBA_RED)
	--Debug.Draw:Line(myPos, myPos + leftDir * 150, Vision.V_RGBA_BLUE)
	--Debug.Draw:Line(myPos, target, Vision.V_RGBA_GREEN)
	
	--Debug:PrintLine("angle: " .. angle)
end

function PerformMelee(self)
	self.behaviorComponent:TriggerEvent("AttackStart")
	self.prevState = self.currentState
	self.currentState = self.states.attacking
	CheckForAttackHit(self)
	StartCoolDown(self, self.meleeCoolDown)
end

function CheckForAttackHit(self)
	--test ray
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
		
		local rayStart = myPos
		local rayEnd = myPos + (newDir * self.attackRange)
		
		--get the collision info
		local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
		local hit, result = Physics.PerformRaycast(rayStart, rayEnd, iCollisionFilterInfo)
		
		
		Debug.Draw:Line(rayStart, rayEnd, Vision.V_RGBA_GREEN)
		
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
	StopRotation(self)
	if self.numSpellsInPlay < self.maxSpellCount then
		if self.currentMana - self.fireballManaCost >= 0 then
			local myDir = -self:GetObjDir_Right()
			self.CreateFireball(self, myDir)
			self:ModifyMana(-self.fireballManaCost)
			StartCoolDown(self, self.spellCoolDown)
		end
	end
end

function ClearPath(self)
	self.lastPoint = nil
	self.nextPoint = nil
	self.path = nil
end

function StopRotation(self)
	self:ResetRotationDelta()
	self.behaviorComponent:SetFloatVar("RotationSpeed", 0)
end

function StartCoolDown(self, coolDownTime)
	self.timeToNextAttack = coolDownTime
end

function ShowPlayerStats(self)
	Debug:PrintAt(G.w * (3 / 4), G.fontSize, "Health: "..self.currentHealth.."/"..self.maxHealth, Vision.V_RGBA_GREEN, G.fontPath)
	Debug:PrintAt(G.w * (3 / 4), G.fontSize * 2, "  Mana: ".. self.currentMana .."/"..self.maxMana, Vision.V_RGBA_BLUE, G.fontPath)
end

function RotateXY(x, y, z, angle)
	local _x = (x * math.cos(angle) ) - (y * math.sin(angle) )
	local _y = (x * math.sin(angle) ) + (y * math.cos(angle) )
	return Vision.hkvVec3(_x, _y, z)
end