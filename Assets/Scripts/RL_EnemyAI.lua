-- new script file
function OnAfterSceneLoaded(self)
	--get the character controller attched to this or assign one if nil
	self.characterController = self:GetComponentOfType("vHavokCharacterController")
	if self.characterController == nil then
		self.AddComponentOfType("vHavokCharacterController")
	end
	
	--set the move speed
	self.moveSpeed = 50
	
	self.optimalDistance = 5
end

function OnThink(self)
	local dt = Timer:GetTimeDiff()
	
	if G.player ~= nil then
		--get the this and the player's position
		local playerPosition = G.player:GetPosition()
		local myPosition = self:GetPosition()
		if myPosition:getDistanceTo(playerPosition) > self.optimalDistance then
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
		end
		
		if self.path then
			self.pathProgress = self.pathProgress + dt * self.moveSpeed

			if self.pathProgress > self.pathLength then
				self.pathProgress = self.pathLength
			end
			
			local point = AI:GetPointOnPath(self.path, self.pathProgress)
			local dir = point - myPosition
			self:SetMotionDeltaWorldSpace(dir)

			if self.pathProgress == self.pathLength then
				self.path = nil
			end
		end	
	else
		Debug:PrintLine("Player not Found")
	end
end