-- new script file
function OnAfterSceneLoaded(self)
	--get and save the character controller component
	self.characterController = self:GetComponentOfType("vHavokCharacterController")
	if self.characterController == nil then
		self.AddComponentOfType("vHavokCharacterController")
	end
		
	-- self.deadZone = self.characterController:GetCapsuleRadius()
	self.deadZone = 75
	
	--create the input map
	self.map = Input:CreateMap("PlayerInputMap")
	
	--set the controls for the input map
	self.map:MapTrigger("CLICK", "MOUSE", "CT_MOUSE_LEFT_BUTTON")
	self.map:MapTrigger("X", "MOUSE", "CT_MOUSE_ABS_X")
	self.map:MapTrigger("Y", "MOUSE", "CT_MOUSE_ABS_Y")
	
	--establish a zero Vector
	self.zeroVector = Vision.hkvVec3(0,0,0)
	
	--set up the tuning values
	self.moveSpeed = 15
	
	self.invalidMouseCursor = Game:CreateTexture("Textures/Cursor/RL_Cursor_Diffuse_Red.tga")
	self.validMouseCursor = Game:CreateTexture("Textures/Cursor/RL_Cursor_Diffuse_Green.tga")
	
	self.mouseCursor = Game:CreateScreenMask(G.w / 2.0, G.h / 2.0, "Textures/Cursor/RL_Cursor_Diffuse_Red.tga")
	self.mouseCursor:SetBlending(Vision.BLEND_ALPHA)
	self.cursorSizeX, self.cursorSizeY  = self.mouseCursor:GetTextureSize()
end

function OnBeforeSceneUnloaded(self)
	--delete the controller map
	Input:DestroyMap(self.map)
	self.map = nil
end

function OnExpose(self)
	
end

function OnThink(self)
	if not G.gameOver then
		local x = self.map:GetTrigger("X")
		local y = self.map:GetTrigger("Y")
		
		if self.map:GetTrigger("CLICK") > 0 then
			UpdateTargetPosition(self, x, y)
		end
		
		if self.path ~= nil then
			NavigatePath(self)
		end
		
		--update the mouse position on screen
		UpdateMouse(self, x, y)
		
		--show the player's stats
		ShowPlayerStats(self)
	end
end

function UpdateTargetPosition(self, mouseX, mouseY)
	local goal = AI:PickPoint(mouseX, mouseY)
	
	if goal ~= nil then
		local start = self:GetPosition()
		local path = AI:FindPath(start, goal, 20.0)
		
		if path ~= nil then
			local numPoints = table.getn(path)
			local endPoint = path[numPoints]
			
			self.pathLength = AI:GetPathLength(path)
			
			if self.pathLength > self.deadZone then
				self.path = path
				self.pathProgress = 0
			end
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
		
		local point = AI:GetPointOnPath(self.path, self.pathProgress)
		local dir = point - self:GetPosition()
		dir:normalize()
		dir = dir * self.moveSpeed
		self:SetMotionDeltaWorldSpace(dir)

		if self.pathLength - self.pathProgress <= self.deadZone then
			self.path = nil
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

function ShowPlayerStats(self)
	Debug:PrintAt(10, 64, "Item Count: " .. self.inventory.itemsCollected, Vision.V_RGBA_WHITE, G.fontPath)
end