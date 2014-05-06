-- new script file

function OnAfterSceneLoaded(self)
	self.item = {}
	GeneratePickupProperties(self)
end

function OnExpose(self)
	--
end

function OnObjectEnter(self, otherObj)
	if otherObj:GetKey() == "Player" then
		otherObj:AddItem(self.item)
		Deactivate(self)
		-- Debug:PrintLine("Triggered") --> yay this works
	end
end

function OnBeforeSceneUnloaded(self)
	--
end

function Deactivate(self)
	self:SetEnabled(false)
	self:SetVisible(false)
end

function GeneratePickupProperties(self)
	self.item.name = "Bag of Stuff"
	self.item.UseCallback = AddHealth
end

function AddHealth(self, character)
	character:ModifyHealth(25)
end