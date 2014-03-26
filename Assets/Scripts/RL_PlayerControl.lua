-- new script file
function OnAfterSceneLoaded(self)
	--get and save the character controller component
	self.characterController = self:GetComponentOfType("vHavokCharacterController")
	if self.characterController == nil then
		self.AddComponentOfType("vHavokCharacterController")
	end
	
	--create the input map
	self.map = Input:CreateMap("PlayerInputMap")
	
	--set the controls for the input map
	--WASD or Arrow keys control for character movement
	self.map:MapTriggerAxis("HORIZONTAL", "KEYBOARD", "CT_KB_D", "CT_KB_A")
	self.map:MapTriggerAxis("HORIZONTAL", "KEYBOARD", "CT_KB_RIGHT", "CT_KB_LEFT")
	self.map:MapTriggerAxis("VERTICAL", "KEYBOARD", "CT_KB_S", "CT_KB_W")
	self.map:MapTriggerAxis("VERTICAL", "KEYBOARD", "CT_KB_DOWN", "CT_KB_UP")
	
	--Button for sneaking
	self.map:MapTrigger("SNEAK", "KEYBOARD", "CT_KB_LSHIFT")
	
	--establish a zero Vector
	self.zeroVector = Vision.hkvVec3(0,0,0)
	
	--set up the tuning values
	self.jogSpeed = 10
	self.sneakSpeed = 5
end

function OnBeforeSceneUnloaded(self)
	--delete the controller map
	Input:DestroyMap(self.map)
	self.map = nil
	
	--delete the screen masks
	--[#todo] move to Scene Script
	Game:DeleteAllUnrefScreenMasks()
end

function OnExpose(self)
	
end

function OnThink(self)
	--set the moveVector
	self.moveVector = self.zeroVector
	
	--get and cache the player input
	local horz = self.map:GetTrigger("HORIZONTAL")
	local vert = self.map:GetTrigger("VERTICAL")
	
	local sneak = self.map:GetTrigger("SNEAK") > 0 
	
	--process the input
	if horz ~= 0 or vert ~= 0 then
		ProcessInput(self, horz, vert, sneak)
	end
end

function ProcessInput(self, horz, vert, sneak)
	
	--set the movement speed
	local moveSpeed = 0
	if sneak then
		moveSpeed = self.sneakSpeed
	else
		moveSpeed = self.jogSpeed
	end
	
	-- move the character left/right
	if vert ~= 0 then
		self.moveVector.x = self.moveVector.x + vert
	end
	
	-- move the character forward/back
	if horz ~= 0 then
		self.moveVector.y = self.moveVector.y + horz
	end
	
	-- normalize the movement vector
	if self.moveVector:getLength() > 1 then
		self.moveVector:normalize()
	end
	
	-- multiply the move vector by the moveSpeed
	self.moveVector = self.moveVector * moveSpeed
	
	-- move the character
	self:SetMotionDeltaWorldSpace(self.moveVector)
end