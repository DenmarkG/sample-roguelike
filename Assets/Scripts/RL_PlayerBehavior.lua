-- new script file
function OnAfterSceneLoaded(self)
	--get the rigidbody attached; if there is none, attach one.
	-- self.rigidBody = self:GetComponentOfType("vHavokRigidBody")
	-- if self.rigidBody == nil then
		-- self.rigidBody = self:AddComponentOfType("vHavokRigidBody")
		-- self.rigidBody:SetMotionType("MOTIONTYPE_KEYFRAMED")
	-- end
	
	self.characterController = self:GetComponentOfType("vHavokCharacterController")
	if self.characterController == nil then
		self.characterController = self:AddComponentOfType("vHavokCharacterController")
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
	self.moveSpeed = 150
	self.rotSpeed = 2
	self.maxSpellCount = 3
	self.spellCoolDown = .75 --how long the player must wait before doing another attack after a spell
	
	self.meleeWeapon = GetWeapon(self)
	self.meleeCoolDown = .5 --how long the player must wait before doing another attack after a melee
	
	self.timeToNextAttack = 0 
	
	self.invalidMouseCursor = Game:CreateTexture("Textures/Cursor/RL_Cursor_Diffuse_Red_32.tga")
	self.validMouseCursor = Game:CreateTexture("Textures/Cursor/RL_Cursor_Diffuse_Green_32.tga")
	
	self.mouseCursor = Game:CreateScreenMask(G.w / 2.0, G.h / 2.0, "Textures/Cursor/RL_Cursor_Diffuse_Red_32.tga")
	self.mouseCursor:SetBlending(Vision.BLEND_ALPHA)
	self.cursorSizeX, self.cursorSizeY  = self.mouseCursor:GetTextureSize()
end

function OnBeforeSceneUnloaded(self)
	--delete the controller map
	Input:DestroyMap(self.map)
	self.map = nil
end

function OnThink(self)
	if not G.gameOver then
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
				--PerformMelee(self)
			end
		end
		
		--update the mouse position on screen
		UpdateMouse(self, x, y)
		
		--show the player's stats
		ShowPlayerStats(self)
	end
end

function PerformMelee(self)
	if self.meleeWeapon ~= nil then
		--check to see if enemy is in front
		local rayStart = self:GetPosition()
		local rayEnd = rayStart + self:GetObjDir() * meleeRange
		
		--get the collision info for the ray
		local iCollisionFilterInfo = Physics.CalcFilterInfo(Physics.LAYER_ALL, 0,0,0)
		local hit, result = Physics.PerformRaycast(rayStart, rayEnd, iCollisionFilterInfo)
		
		local enemy = nil
		
		if hit == true then
			if result ~= nil then
				local hitObj = result["HitObject"]
				
				if hitObj:GetKey() == "Enemy" then
					enemy = hitObj
				end
			end
		end
		
		self.meleeWeapon:Attack(enemy)
		StartCoolDown(self, self.meleeCoolDown)
	end
end

function CastSpell(self)
	if self.numSpellsInPlay < self.maxSpellCount then
		self.CreateFireball(self)
		StartCoolDown(self, self.spellCoolDown)
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
		end
	end
end

function NavigatePath(self)
	if self.path ~= nil then
		local dt = Timer:GetTimeDiff()
		
		self.pathProgress = self.pathProgress + dt * self.moveSpeed

		if self.pathProgress > self.pathLength then
			self.pathProgress = self.pathLength
		end
		
		--get the next point on the path
		local point = AI:GetPointOnPath(self.path, self.pathProgress)
		local dir = point - self:GetPosition()
		
		--[[
		#todo
		This section currently has several bugs
		in order to move on to other tasks, I'm setting the position rather than
		using movement/rotation delta. 
		--]]
		
		--Make the player rotate toward the direction of movement
		-- local objDir = self:GetObjDir()
		-- objDir:setInterpolate(objDir, dir, dt * self.rotSpeed)
		-- self:SetDirection(objDir)
		-- self:IncRotationDelta( Vision.hkvVec3(objDir.x, 0, 0) )
		
		dir:normalize()
		-- dir = dir * 15
		self:SetMotionDeltaWorldSpace(dir)
		-- self:SetPosition(point)
		-- Debug:PrintLine("".. dir)
		
		if self.pathProgress == self.pathLength then
			self.path = nil
			self:ResetRotationDelta()
		end
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

function StartCoolDown(self, coolDownTime)
	self.timeToNextAttack = coolDownTime
end

function GetWeapon(self)
	local numChildren = self:GetNumChildren()
	
	for i = 0, numChildren - 1, 1 do
		local entity = self:GetChild(i)
		
		if entity ~= nil then
			if entity:GetKey() == "MeleeWeapon" then 
				return entity
			end
		end
	end
end

function ShowPlayerStats(self)
	--Debug:PrintAt(10, 64, "Item Count: " .. self.inventory.itemsCollected, Vision.V_RGBA_WHITE, G.fontPath)
end