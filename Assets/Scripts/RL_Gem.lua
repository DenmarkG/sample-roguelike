-- new script file

function OnAfterSceneLoaded(self)
	self.rotSpeed = .5
end

-- function OnThink(self)
	-- local step = self.rotSpeed * Timer:GetTimeDiff()
	
	-- local objDir = self:GetObjDir()
	-- local leftDir = self:GetObjDir_Right()
	-- local zHolder = objDir.z
	-- objDir:setInterpolate(objDir, leftDir, step)
	-- objDir.z = zHolder
	-- self:SetRotationDelta(objDir)
	-- self:SetDirection(objDir)
-- end

function OnObjectEnter(self, otherObj)
	if (otherObj:GetKey() == "Player") then
		otherObj:AddGem()
		Deactivate(self)
	end
end

function OnBeforeSceneUnloaded(self)
	Game:DeleteAllUnrefScreenMasks()
end

function Deactivate(self)
	self:SetEnabled(false)
	
	for i = 0, self:GetNumChildren(), 1 do
		local entity = self:GetChild(i)
		if entity ~= nil then
			entity:SetVisible(false)
		end
	end
end