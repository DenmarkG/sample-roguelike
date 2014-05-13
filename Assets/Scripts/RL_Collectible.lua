-- new script file

function OnAfterSceneLoaded(self)
	self.item = {}
	self.item.name = ""..self.type.."Potion"
	
	self.healthTexturePath = "Textures/Potions/RL_HealthPotion_DIFFUSE.tga"
	self.manaTexturePath = "Textures/Potions/RL_ManaPotion_DIFFUSE.tga"
	self.powerTexturePath = "Textures/Potions/RL_PowerPotion_DIFFUSE.tga"
	
	GeneratePickupProperties(self)
end

function OnExpose(self)
	self.type = "Health or Power or Mana"
	self.itemValue = 25
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
	self.item.value = self.itemValue
	local imagePath = ""
	
	if self.item.name == "HealthPotion" then
		self.item.UseCallback = AddHealth
		imagePath = self.healthTexturePath
	elseif self.item.name == "ManaPotion" then
		self.item.UseCallback = AddMana
		imagePath = self.manaTexturePath
	else
		self.item.UseCallback = AddPower
		imagePath = self.powerTexturePath
	end
	
	--for drawing the inventory item on screen
	self.item.itemImage = Game:CreateScreenMask(0, 0, "".. imagePath)
	self.item.itemImage:SetVisible(false)
	self.item.itemImage:SetZVal(0)
end

function AddHealth(self, character)
	character:ModifyHealth(self.value)
end

function AddMana(self, character)
	character:ModifyMana(self.value)
end

function AddPower(self, character)
	character:ModifyPower(self.value)
end