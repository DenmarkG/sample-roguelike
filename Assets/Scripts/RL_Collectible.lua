--[[
Author: Denmark Gibbs
This script:
	-sets up each item's properties and functions based on the name established in the OnExpose function
	
This should be attached to the trigger of a collectible. The model file associated with the collectible 
should be a child of the trigger this is attached to
--]]

--callback function that is called after the scene has been loaded but before the first Think Loop
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

--This function allows variables to be tuned in the components window
function OnExpose(self)
	self.type = "Health or Power or Mana"
	self.itemValue = 25
end

--This callback function is called whenever an object (otherObj) enters the trigger that this script is attached to.
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

--this callback is called automatically before the scene is unloaded
function OnBeforeSceneUnloaded(self)
	--delete the screen masks
	Game:DeleteAllUnrefScreenMasks()
end

--function to be called when the trigger has been hit by the player, to prevent re-use
function Deactivate(self)
	--deactivate the trigger
	self:SetEnabled(false)

	--hide the item and its children
	for i = 0, self:GetNumChildren(), 1 do
		local entity = self:GetChild(i)
		if entity ~= nil then
			entity:SetVisible(false)
		end
	end
end

--[[
this function is called when the scene starts, and sets up the appropriate variables and functions
for the pickup item. this is done so that the item type can be changed in the OnExpose function easily
--]]
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

--[[
The following functions are all to be used to modify the player in some way when the player uses an
item from the inventory.
--]]
function AddHealth(self, character)
	--add Health to the player
	character:ModifyHealth(self.value)
	
	--set up and play the sound if it is not nil
	local useSound = Fmod:CreateSound(character:GetPosition(), "Sounds/RL_PotionSound.wav", false)
	if useSound ~= nil then
		useSound:Play()
	end
end

function AddMana(self, character)
	--add Mana to the player
	character:ModifyMana(self.value)
	
	--set up and play the sound if it is not nil
	local useSound = Fmod:CreateSound(character:GetPosition(), "Sounds/RL_PotionSound.wav", false)
	if useSound ~= nil then
		useSound:Play()
	end
end

function AddPower(self, character)
	--add Attack power to the player
	character:ModifyPower(self.value)
	
	--set up and play the sound if it is not nil
	local useSound = Fmod:CreateSound(character:GetPosition(), "Sounds/RL_PotionSound.wav", false)
	if useSound ~= nil then
		useSound:Play()
	end
end