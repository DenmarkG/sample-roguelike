-- new script file
function OnAfterSceneLoaded(self)
	
	--grab the behavior component
	self.behaviorComponent = self:GetComponentOfType("vHavokBehaviorComponent")
	if self.behaviorComponent == nil then
		self.behaviorComponent = self:AddComponentOfType("vHavokBehaviorComponent")
	end
	
	--create the input map
	self.map = Input:CreateMap("PlayerInputMap")
	
	--set the controls for the input map
	--mouse movement controls:
	self.map:MapTrigger("CLICK", "MOUSE", "CT_MOUSE_LEFT_BUTTON")
	self.map:MapTrigger("X", "MOUSE", "CT_MOUSE_ABS_X")
	self.map:MapTrigger("Y", "MOUSE", "CT_MOUSE_ABS_Y")
	--Interaction controls:
	self.map:MapTrigger("MAGIC", "KEYBOARD", "CT_KB_F")
	self.map:MapTrigger("MELEE", "KEYBOARD", "CT_KB_SPACE")
	
	--establish a zero Vector
	self.zeroVector = Vision.hkvVec3(0,0,0)
	
	--set up the tuning values
	self.moveSpeed = 180
	self.rotSpeed = 90 --positive rotates left
	self.maxSpellCount = 3
	self.spellCoolDown = .75 --how long the player must wait before doing another attack after a spell
	self.meleeCoolDown = 5 --how long the player must wait before doing another attack after a melee
	self.timeToNextAttack = 0 
	
	self.invalidMouseCursor = Game:CreateTexture("Textures/Cursor/RL_Cursor_Diffuse_Red_32.tga")
	self.validMouseCursor = Game:CreateTexture("Textures/Cursor/RL_Cursor_Diffuse_Green_32.tga")
	
	self.mouseCursor = Game:CreateScreenMask(G.w / 2.0, G.h / 2.0, "Textures/Cursor/RL_Cursor_Diffuse_Red_32.tga")
	self.mouseCursor:SetBlending(Vision.BLEND_ALPHA)
	self.cursorSizeX, self.cursorSizeY  = self.mouseCursor:GetTextureSize()
	
	self.states = {}
	self.states.walking = "walking"
	self.states.idle = "idle"
	self.states.attacking = "attacking"
	
	self.currentState = self.states.idle
	
	--need to add vars for AI pathfinding
	self.goalRadius = .05 --how far the character should stop from a goal point
	--distance from point
end

function OnBeforeSceneUnloaded(self)
	--delete the controller map
	Input:DestroyMap(self.map)
	self.map = nil
end

function OnThink(self)
	if not G.gameOver then
		if self.currentState ~= self.states.attacking then
			
			local x = self.map:GetTrigger("X")
			local y = self.map:GetTrigger("Y")
			
			local magic = self.map:GetTrigger("MAGIC") > 0
			local melee = self.map:GetTrigger("MELEE") > 0
			
			if self.map:GetTrigger("CLICK") > 0 then
				UpdateTargetPosition(self, x, y)
			end
			
			--follow the path if one exists
			NavigatePath(self)
			
			if self.timeToNextAttack > 0 then
				self.timeToNextAttack = self.timeToNextAttack - Timer:GetTimeDiff()
			elseif self.timeToNextAttack <= 0 then
				self.timeToNextAttack = 0
							
				if magic then
					CastSpell(self)
				elseif melee then
					PerformMelee(self)
				end
			end
			
			--update the mouse position on screen
			UpdateMouse(self, x, y)
			
			--show the player's stats
			ShowPlayerStats(self)
		else
			local attackStopped = self.behaviorComponent:WasEventTriggered("AttackStop")
			if attackStopped then
				self.currentState = self.states.idle
			end
		end
	end
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
		end
	end
end

function NavigatePath(self)
	if self.path ~= nil then
		--get the next point on the path
		local nextPoint = AI:GetPointOnPath(self.path, self.pathProgress)
		local dir = nextPoint - self:GetPosition()
		
		local distanceToNext = self:GetPosition():getDistanceTo(nextPoint)
		
		--if the distance to the next point is < than the goal radius, move to the next point
		if distanceToNext <= self.goalRadius then
			self.nextPoint = nextPoint
			self.pathProgress = self.pathProgress + self:GetPosition():getDistanceTo(self.lastPoint)
		end
		
		--set the nextpoint as the current point
		--set the currentPoint as the previous point
		--update the path progress
		
		if self.pathProgress >= self.pathLength then
			self.pathProgress = self.pathLength
		end
		
		RotateToTarget(self, nextPoint)
		
		if self.currentState == self.states.idle then		
			self.behaviorComponent:TriggerEvent("MoveStart")
			self.currentState = self.states.walking
		end
		
		if self.pathProgress == self.pathLength then
			self.path = nil
			self:ResetRotationDelta()
			self.behaviorComponent:TriggerEvent("MoveStop")
			self.behaviorComponent:SetFloatVar("RotationSpeed", 0)
			self.currentState = self.states.idle
			self.lastPoint = nil
			self.nextPoint = nil
		else
			if distanceToNext < self.goalRadius then
				self.nextPoint = nextPoint
			end
		end
	end
	
	-- if self.path ~= nil then
	-- local dt = Timer:GetTimeDiff()
	
	-- -- [todo] change this!!!
	-- self.pathProgress = self.pathProgress + dt * self.moveSpeed

	-- if self.pathProgress > self.pathLength then
		-- self.pathProgress = self.pathLength
	-- end
	
	-- -- get the next point on the path
	-- local point = AI:GetPointOnPath(self.path, self.pathProgress)
	-- local dir = point - self:GetPosition()
	
	-- RotateToTarget(self, point)
	
	-- if self.currentState == self.states.idle then		
		-- self.behaviorComponent:TriggerEvent("MoveStart")
		-- self.currentState = self.states.walking
	-- end
	
	-- if self.pathProgress == self.pathLength then
		-- self.path = nil
		-- self:ResetRotationDelta()
		-- self.behaviorComponent:TriggerEvent("MoveStop")
		-- self.behaviorComponent:SetFloatVar("RotationSpeed", 0)
		-- self.currentState = self.states.idle
	-- end
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
	local deadZone = 20
	local myDir = -self:GetObjDir_Right()
	local myPos = self:GetPosition()
	local leftDir = self:GetObjDir()
	local sign = 1 
	local targetDir = (target - myPos):getNormalized()
	local angle = myDir:getAngleBetween(targetDir) -- (90 * sign)
		
	if leftDir:dot(targetDir) < 0 then
		--Debug:PrintLine("I'm on happy side!")
		sign = -1
	end
	
	if math.abs(angle) > deadZone then
		self.behaviorComponent:SetFloatVar("RotationSpeed", self.rotSpeed * sign * angle)
	else
		self.behaviorComponent:SetFloatVar("RotationSpeed", 0)
	end	
	
	--Debug.Draw:Line(myPos, myPos + myDir * 150, Vision.V_RGBA_RED)
	--Debug.Draw:Line(myPos, myPos + leftDir * 150, Vision.V_RGBA_BLUE)
	--Debug.Draw:Line(myPos, target, Vision.V_RGBA_GREEN)
	
	--Debug:PrintLine("angle: " .. angle)
end

function PerformMelee(self)
	self.behaviorComponent:TriggerEvent("AttackStart")
	--self.currentState = self.states.attacking -- <--this currently crashes vForge
	--StartCoolDown(self, self.meleeCoolDown)
end

function CastSpell(self)
	if self.numSpellsInPlay < self.maxSpellCount then
		local myDir = -self:GetObjDir_Right()
		self.CreateFireball(self, myDir)
		StartCoolDown(self, self.spellCoolDown)
	end
end

function StartCoolDown(self, coolDownTime)
	self.timeToNextAttack = coolDownTime
end

function ShowPlayerStats(self)
	--Debug:PrintAt(10, 64, "Item Count: " .. self.inventory.itemsCollected, Vision.V_RGBA_WHITE, G.fontPath)
end