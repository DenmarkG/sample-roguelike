-- new script file

function OnAfterSceneLoaded(self)
	self.properties = {}
	GeneratePickupProperties(self)
end

function OnExpose(self)
	--
end

function OnObjectEnter(self, otherObj)
	Debug:PrintLine("Triggered")
	if otherObj:GetKey() == "Player" then
		otherObj:AddItem(otherObj, self.properties)
		
	end
end

function OnBeforeSceneUnloaded(self)
	--
end

function GeneratePickupProperties(self)
	--
end