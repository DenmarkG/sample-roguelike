--[[
Author: Denmark Gibbs
This script handles:
	-the management of the player's inventory
	-display of the items when the "INVENTORY" Trigger is activated by the player
	-selection of an item when the display is visible
	-loading of previously saved items

This should be attached to the player
--]]


--this callback function is invoked automatically once the scene has been loaded
function OnAfterSceneLoaded(self)
	--loads items if the level is greater than 1
	if G.currentLevel > 1 then
		LoadItems(self)
	end
	
	--first we make sure that the inventory exists,
	--if it doesn't create it and set it to the default values
	if self.inventory == nil then
		--create the table that will store the items in the inventory
		self.inventory = {}
		--set the number of maximum items to the value created in the OnExpose function
		self.maxItems = self.maxInventoryItems
		--set the initial item count to zero
		self.itemCount = 0
	end	
	
	--the player's collected gem count
	self.gemsCollected = 0
	
	--tells whether or not the inventory display is curretnly visible
	self.inventoryIsVisible = false
	
	--positioning varibles for display
	self.xSize = G.w / self.maxItems --textures will be square, so the xSize will act as both vertical and horizontal size
	self.vertStartPos = G.h * 3 / 4
	
	--the following are functios in this script, assigned to variables so they can be used by other scripts at runtime
	self.AddItem = AddNewItem
	self.AddGem = AddNewGem
	self.ToggleInventory = InventoryToggled
	self.InventoryItemClicked = ItemClicked
	self.SaveInventory = SaveItems
	self.LoadInventory = LoadItems
	self.Clear = ClearInventory
	
	--create a ScreenMask to represent an empty item slot when the inventory is empty
	self.placeHolderTextures = {}
	self.placeHolderTexturePath = "Textures/Potions/RL_EmptyPotion_DIFFUSE.tga"
	CreatePlaceHolderTextures(self)
end

--the OnExpose function allows variables to be changed in the component panel
function OnExpose(self)
	self.maxInventoryItems = 8
end

--[[
This function creates place holder screen masks that will represent empty spaces in the player inventory.
We do this so that there is still something that shows up on screen when the player toggles the inventory, 
even if the inventory is empty.
--]]
function CreatePlaceHolderTextures(self)
	for i = 1, self.maxInventoryItems, 1 do
		--store the mask in a local variable
		local emtpyMask = Game:CreateScreenMask(G.w / 2, G.h / 2 , "".. self.placeHolderTexturePath)
		--set the mask's visibility, blending, size, and position on screen
		emtpyMask:SetBlending(Vision.BLEND_ALPHA)
		emtpyMask:SetVisible(false)
		emtpyMask:SetTargetSize(self.xSize, self.xSize) --set the size of the item based on a pre-calculated value
		emtpyMask:SetPos( (i-1) * self.xSize, self.vertStartPos) --set the position based on the size
		self.placeHolderTextures[i] = emtpyMask
	end
end

--this function is called when the player presses the button to toggle the inventory on or off
function InventoryToggled(self)
	if not self.inventoryIsVisible then --if the inventory is not visible show it
		--iterate through each item in the inventory
		for i = 1, self.maxInventoryItems, 1 do
			--cache the currently selected item
			local currentItem = self.inventory[i]
			--check to see if the item is nil
			if currentItem ~= nil then
				--get the item image, and set its visibility, blending, size, and position on screen
				currentItem.itemImage:SetVisible(true)
				currentItem.itemImage:SetBlending(Vision.BLEND_ALPHA)
				currentItem.itemImage:SetTargetSize(self.xSize, self.xSize) --set the size of the item based on a pre-calculated value
				currentItem.itemImage:SetPos( (i-1) * self.xSize, self.vertStartPos) --set the position based on the size
			else
				local emptyMask = self.placeHolderTextures[i]
				emptyMask:SetVisible(true)
			end
		end
		
		--tell the game the inventory is now visible
		self.inventoryIsVisible = true
	else --if the inventory is on screen, hide it
		
		--iterate through each item in the inventory and hide it
		for i = 1, self.maxInventoryItems, 1 do
			--cache the current item
			local currentItem = self.inventory[i]
			if currentItem ~= nil then
				--hide the screen mask of the item
				currentItem.itemImage:SetVisible(false)
			else
				--if there is no item in the current slot, hide the placeholder mask
				local emptyMask = self.placeHolderTextures[i]
				emptyMask:SetVisible(false)
			end
		end
		
		--tell the game the inventory is no longer visible
		self.inventoryIsVisible = false
	end
end

--[[
This function is called when the inventory is visbile and the player clicks a location.
The function then determines if the player clicked on an item and uses that item
*note: Y values start and zero on the top and increase going down the screen space
--]]
function ItemClicked(self, xPos, yPos)
	--this should only be used if the inventory is visible
	if self.inventoryIsVisible then
		--cache the upper and lower bounds of the inventory items on screen
		local yUpperBound = self.vertStartPos + self.xSize
		local ylowerBound = self.vertStartPos 
		
		--only continue if the click location is between the upper and lower bounds of the 
		if yPos < yUpperBound and yPos > ylowerBound then
			--get the right boundary of the inventory images
			local xUpperBound = self.xSize * self.itemCount
			--only continue if the click location is left of the right boundary
			if xPos < xUpperBound then
				--set the lower bound to 0
				local xLowerBound = 0
				
				--search through the images to find the index of the item based on the click location
				while xLowerBound <= xUpperBound do
					--divide the space between the upper and lower bounds in half
					local middle = math.floor( (xUpperBound + xLowerBound) / 2)
					
					--if the mouse position lies on the image in the 'middle'...
					if xPos >= middle and xPos < middle + self.xSize then
						--calculate the index of the item that was clicked
						local index = math.floor(xPos / self.xSize)
						--use that index to get the item from the inventory
						local item = self.inventory[index + 1]
						--use the callback function on that item
						item:UseCallback(self)
						--hide the item
						item.itemImage:SetVisible(false)
						--if that was the last item, set the inventory to empty
						if self.itemCount == 1 then
							self.inventory = {}
							--update the item count
							self.itemCount = 0
							--hide the inventory
							self.ToggleInventory(self)
						--if that was not the last item, simply remove the item
						else
							table.remove(self.inventory, index + 1)
							--hide the rest of the inventory
							self.ToggleInventory(self)
							--update the item count
							self.itemCount = self.itemCount - 1
						end
						
						--return that the item was selected successfully
						return true
					--if the click was left of the middle then search again with the middle as the upper bound
					elseif xPos < middle then
						xUpperBound = middle
					--if the click was right of the middle then search again with the middle as the lower bound
					elseif xPos >= middle then
						xLowerBound = middle
					end
				end
			end
		end
		
		--if this point is reached, the item was not selected successfully
		return false
	end
end

--function that updates the number of gems the player has collected
function AddNewGem(self)
	self.gemsCollected = self.gemsCollected + 1
end

--[[
This function is called whenever the player picks up an item.
If the item is not already in the inventory, and the inventory is not full,
then the item is added to the inventory
--]]
function AddNewItem(self, newItem)
	--first we make sure that the inventory exists,
	--if it doesn't create it and set it to the default values
	if self.inventory == nil then
		--create the table that will store the items in the inventory
		self.inventory = {}
		--set the number of maximum items to the value created in the OnExpose function
		self.maxItems = self.maxInventoryItems
		--set the initial item count to zero
		self.itemCount = 0
	end
	
	--assume that the item is not in the inventory...
	local notInInventory = true
	
	--then check all the items in the inventory
	if self.itemCount > 0 then
		for i = 0, table.getn(self.inventory), 1 do
			--cache the currently selected item in the inventory to compare with the new item
			local item = self.inventory[i]
			
			--if the items are the same, then the new item is already in the inventory
			if newItem == item then
				notInInventory = false
			end
		end
	end
	
	--if the item is not in the inventory, and the inventory is not full then add the new item
	if notInInventory and not (self.itemCount >= self.maxItems) then
		--add the new item to the first available slot in the table
		self.inventory[self.itemCount + 1] = newItem
		--increase the item count by one
		self.itemCount = self.itemCount + 1
	end
	
	--Since the inventory has changed, we want to draw the new texture if the inventory is visible
	if self.inventoryIsVisible then
		--get the current placeholder mask located in the position we want to draw the new item
		local emptyMask = self.placeHolderTextures[self.itemCount]
		--set that placeholder to invisible
		emptyMask:SetVisible(false)
		--set the new item to visible
		newItem.itemImage:SetVisible(true)
		--set the blending on the new item's mask
		newItem.itemImage:SetBlending(Vision.BLEND_ALPHA)
		--set the size of the new screen mask
		newItem.itemImage:SetTargetSize(self.xSize, self.xSize) --set the size of the item based on a pre-calculated value
		--set the position of the new screen mask
		newItem.itemImage:SetPos( (self.itemCount-1) * self.xSize, self.vertStartPos) --set the position based on the size
	end
end

--[[
This function empties the inventory of all items, and sets the count back to zero.
It is called when the player dies
--]]
function ClearInventory(self)
	--loop through each item in the player's inventory
	if player.itemCount ~= nil and player.itemCount ~= 0 then
		for i = 1, player.itemCount, 1 do 
			--remove each item
			table.remove(self.inventory, i)
		end
		
		--reset the inventory table
		player.inventory = {}
		--set the item count back to zero
		player.itemCount = 0
	end
end

--[[
This function is used to save all the items in the inventory once a level has been successfully completed.
It is called by the level manager before the next scene is loaded
--]]
function SaveItems(self)
	if player.itemCount == nil or player.itemCount == 0 then
		--if the inventory is empty, the save no items, only a count of zero.
		--this count will be used to determine the number of items to load.
		PersistentData:SetNumber("PlayerStats", "itemCount", 0)
	else
		--if the inventory is not empty...
		
		--first save the number of items; This count will be used to determine the number of items to load.
		PersistentData:SetNumber("PlayerStats", "itemCount", player.itemCount)
		--then loop through each item
		for i = 1, player.itemCount, 1 do
			--save a name for each item based on the number of items looped through
			--this will prevent saving exact duplicates, and make loading easier
			local localName = "item"..i
			--cache the currently selected item
			local item = player.inventory[i]
			--save the name, image path, and value for the currently selected item
			PersistentData:SetString("Items", localName..".name", item.name)
			PersistentData:SetString("Items", localName..".imagePath", item.imagePath)
			PersistentData:SetString("Items", localName..".value", item.value)
		end
	end
end

--[[
This function is used to Load previously saved inventory data.  
It is called by the level manager at the beginning of any level after the first level.
--]]
function LoadItems(self)
	--first load the number of items that was previously saved.
	local itemCount = PersistentData:GetNumber("PlayerStats", "itemCount", 0)
	--if the number of items saved was greater than zero, then load the items that were saved
	if itemCount ~= 0 then
		--loop through each item, up to the number of items saved
		for i = 1, itemCount, 1 do 
			--since we saved each item with a unique name, we must load each the same way
			local localName = "item"..i
			--the item's data representation of the item is a table, so create that now.
			local item = {}
			--load the name, image path, and value that was previously saved.
			item.name = PersistentData:GetString("Items", localName..".name", "HealthPotion")
			item.imagePath = PersistentData:GetString("Items", localName..".imagePath", "Textures/Potions/RL_HealthPotion_DIFFUSE.tga")
			item.value = PersistentData:GetString("Items", localName..".value", 7)
			--pass the item to the reload item function to create the rest of the information based on the data that was loaded.
			--this function will then add the item to the inventory
			ReloadExistingItem(self, item)
		end
	end
end

--[[
This function is called whenever a previously saved item is loaded. 
It works similarly to the way that the GeneratePickupProperties function works on the Collectible script.
This function then adds the item to the inventory once the properties have been generated.
--]]
function ReloadExistingItem(self, item)
	--because the order of Callback functions cannot be guaranteed, it is possible the inventory hasn't be created yet when this funciton is called.
	--if that is the case, we need to create the inventory and set it to the default values. 
	if self.inventory == nil then
		--create the table that will store the items in the inventory
		self.inventory = {}
		--set the number of maximum items to the value created in the OnExpose function
		self.maxItems = self.maxInventoryItems
		--set the initial item count to zero
		self.itemCount = 0
	end	
	
	--assign the proper callback function based on the item name. 
	if item.name == "HealthPotion" then
		item.UseCallback = AddHealth
	elseif item.name == "ManaPotion" then
		item.UseCallback = AddMana
	else
		item.UseCallback = AddPower
	end
	
	--create the ScreenMask that will represent the item when the inventory is displayed
	item.itemImage = Game:CreateScreenMask(0, 0, "".. item.imagePath)
	--hide the new ScreenMask
	item.itemImage:SetVisible(false)
	--set the depth of the ScreenMask so it will draw over the rest of the scene
	item.itemImage:SetZVal(0)
	--add the item to the inventory
	AddNewItem(self, item)
end

--[[
The following functions are all used to modify the player in some way when the player uses an
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