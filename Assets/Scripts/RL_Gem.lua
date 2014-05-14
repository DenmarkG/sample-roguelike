-- new script file

function OnAfterSceneLoaded(self)
	self.rotSpeed = .5
end

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