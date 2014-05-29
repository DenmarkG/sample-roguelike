--[[
Author: Denmark Gibbs
This script:
	-sets up each item's properties and functions based on the name established in the OnExpose function
	
This should be attached to the trigger of a collectible. The model file associated with the collectible 
should be a child of the trigger this is attached to
--]]

function OnAfterSceneLoaded(self)
	--the representation of the item itself is a table
	self.item = {}
	
	--appending to the name from OnExpose
	self.item.name = ""..self.type.."Potion"
	
	--create the texture path for each potion type
	self.healthTexturePath = "Textures/Potions/RL_HealthPotion_DIFFUSE.tga"
	self.manaTexturePath = "Textures/Potions/RL_ManaPotion_DIFFUSE.tga"
	self.powerTexturePath = "Textures/Potions/RL_PowerPotion_DIFFUSE.tga"
	
	--sets the item properties based on name
	GeneratePickupProperties(self)
end

function OnExpose(self)
	self.type = "Health or Power or Mana"
	self.itemValue = 25
end

function OnObjectEnter(self, otherObj)
	--if hte object that enters the trigger is the player, add this item to the player's inventory
	if otherObj:GetKey() == "Player" then
		if self.item ~= nil then
			otherObj:AddItem(self.item)
		end
		
		--remove the item from the scene
		Deactivate(self)
	end
end

function OnBeforeSceneUnloaded(self)
	--delete the screen masks
	Game:DeleteAllUnrefScreenMasks()
end

function Deactivate(self)
	--deactivate the trigger
	self:SetEnabled(false)

	--hide the item
	for i = 0, self:GetNumChildren(), 1 do
		local entity = self:GetChild(i)
		if entity ~= nil then
			entity:SetVisible(false)
		end
	end
end

function GeneratePickupProperties(self)
	self.item.value = self.itemValue
	local imagePath = ""
	
	--set the functions and images for the item based on it's name
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
	
	--set the variables for drawing the inventory item on screen
	self.item.imagePath = imagePath
	self.item.itemImage = Game:CreateScreenMask(0, 0, "".. imagePath)
	self.item.itemImage:SetVisible(false)
	self.item.itemImage:SetZVal(0)
end

function AddHealth(self, character)
	character:ModifyHealth(self.value)
	local useSound = Fmod:CreateSound(character:GetPosition(), "Sounds/RL_PotionSound.wav", false)
	if useSound ~= nil then
		useSound:Play()
	end
end

function AddMana(self, character)
	character:ModifyMana(self.value)
	local useSound = Fmod:CreateSound(character:GetPosition(), "Sounds/RL_PotionSound.wav", false)
	if useSound ~= nil then
		useSound:Play()
	end
end

function AddPower(self, character)
	character:ModifyPower(self.value)
	local useSound = Fmod:CreateSound(character:GetPosition(), "Sounds/RL_PotionSound.wav", false)
	if useSound ~= nil then
		useSound:Play()
	end
end