-- new script file

function OnAfterSceneLoaded(self)
	self.item = {}
	
	self.healthTexturePath = "Textures/Potions/RL_HealthPotion_DIFFUSE.tga"
	self.manaTexturePath = "Textures/Potions/RL_ManaPotion_DIFFUSE.tga"
	
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
	Game:DeleteAllUnrefScreenMasks()
end

function Deactivate(self)
	self:SetEnabled(false)
	self:SetVisible(false)
end

function GeneratePickupProperties(self)
	self.item.name = "HealthPotion"
	self.item.value = 25
	self.item.UseCallback = AddHealth
	
	--for drawing the inventory item on screen
	local imagePath = self.healthTexturePath
	self.item.itemImage = Game:CreateScreenMask(0, 0, "".. imagePath)
	self.item.itemImage:SetVisible(false)
end

function AddHealth(self, character)
	character:ModifyHealth(self.value)
end