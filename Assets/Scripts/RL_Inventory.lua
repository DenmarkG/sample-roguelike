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
	
	--set up the inventory if it has not be created already
	if self.inventory == nil then
		self.inventory = {}
		self.maxItems = 8
		self.itemCount = 0
	end	
	
	--the player's collected gem count
	self.gemsCollected = 0
	
	--tells whether or not the inventory display is curretnly visible
	self.inventoryIsVisible = false
	
	--positioning varibles for display
	self.xSize = G.w / self.maxItems --textures will be square, so the xSize will act as both vertical and horizontal size
	self.vertStartPos = G.h * 3 / 4
	
	--functios to be used by other scripts
	self.AddItem = AddNewItem
	self.AddGem = AddNewGem
	self.ToggleInventory = InventoryToggled
	self.InventoryItemClicked = ItemClicked
	self.SaveInventory = SaveItems
	self.LoadInventory = LoadItems
	self.Clear = ClearInventory
end

--this function is called when the player presses the button to toggle the inventory on or off
function InventoryToggled(self)
	--if the inventory is not visible show it
	if not self.inventoryIsVisible then
		--if the inventory has items in it, show screen masks associated with them
		if self.itemCount > 0 then
			--iterate through each item in the inventory
			for i = 1, table.getn(self.inventory), 1 do
				--cache the currently selected item
				local currentItem = self.inventory[i]
				--get the item image, and set its visibility, blending, size, and position on screen
				currentItem.itemImage:SetVisible(true)
				currentItem.itemImage:SetBlending(Vision.BLEND_ALPHA)
				currentItem.itemImage:SetTargetSize(self.xSize, self.xSize) --set the size of the item based on a pre-calculated value
				currentItem.itemImage:SetPos( (i-1) * self.xSize, self.vertStartPos) --set the position based on the size
			end
			
			--tell the game the inventory is now visible
			self.inventoryIsVisible = true
		end
	--if the inventory is on screen, hide it
	else
		--iterate through each item in the inventory and hide it
		if self.itemCount > 0 then
			for i = 1, table.getn(self.inventory), 1 do
				--cache the current item
				local currentItem = self.inventory[i]
				
				--hide the screen mask of the item
				currentItem.itemImage:SetVisible(false)
			end
			
			--tell the game the inventory is no longer visible
			self.inventoryIsVisible = false
		end
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

-------------------------------------------------------------------------------------------
function AddNewItem(self, newItem)
	-- Debug:PrintLine("Add Item called")
	-- Debug:PrintLine(""..self.maxItems)
	
	if self.inventory == nil then
		-- Debug:PrintLine("self.inventory == nil")
		self.inventory = {}
		self.maxItems = 8
		self.itemCount = 0
	end
	
	local notInInventory = true
	if self.itemCount > 0 then
		-- Debug:PrintLine("self.itemCount > 0")
		for i = 0, table.getn(self.inventory), 1 do
			local item = self.inventory[i]
			if newItem == item then
				notInInventory = false
			end
		end
	end

	if notInInventory and not (self.itemCount >= self.maxItems) then
		-- Debug:PrintLine("notInInventory and not (self.itemCount >= self.maxItems)")
		-- Debug:PrintLine("inside!")
		
		if self.itemCount > 0 then
			self.inventory[self.itemCount + 1] = newItem
			--Debug:PrintLine(""..newItem.name.." "..newItem.value)
		else
			self.inventory[1] = newItem
			--Debug:PrintLine(""..newItem.name.." "..newItem.value)
		end
		
		self.itemCount = self.itemCount + 1
	end
	
	-- Debug:PrintLine(""..self.itemCount)
end

function SaveItems(self)
	--player inventory
	if player.itemCount == nil or player.itemCount == 0 then
		PersistentData:SetNumber("PlayerStats", "itemCount", 0)
	else
		PersistentData:SetNumber("PlayerStats", "itemCount", player.itemCount)
		for i = 1, player.itemCount, 1 do 
			local localName = "item"..i
			local item = player.inventory[i]
			PersistentData:SetString("Items", localName..".name", item.name)
			PersistentData:SetString("Items", localName..".imagePath", item.imagePath)
			PersistentData:SetString("Items", localName..".value", item.value)
		end
	end
end

function LoadItems(self)
	-- player inventory
	local itemCount = PersistentData:GetNumber("PlayerStats", "itemCount", 0)
	if itemCount ~= 0 then
		-- Debug:PrintLine("itemCount = "..itemCount)
		for i = 1, itemCount, 1 do 
			local localName = "item"..i
			local item = {}
			item.name = PersistentData:GetString("Items", localName..".name", "HealthPotion")
			item.imagePath = PersistentData:GetString("Items", localName..".imagePath", "Textures/Potions/RL_HealthPotion_DIFFUSE.tga")
			item.value = PersistentData:GetString("Items", localName..".value", 7)
			-- Debug:PrintLine("Reload func is not nil")
			ReloadExistingItem(self, item)
		end
	end
end

function ClearInventory(self)
	if player.itemCount ~= nil and player.itemCount ~= 0 then
		for i = 1, player.itemCount, 1 do 
			table.remove(self.inventory, i)
		end
		
		self.inventory = {}
		self.itemCount = 0
	end
end

function ReloadExistingItem(self, item)
	if self.inventory == nil then
		Debug:PrintLine("Inventory not nil anymore")
		self.inventory = {}
		self.maxItems = 8
		self.itemCount = 0
	end	
	
	if item.name == "HealthPotion" then
		item.UseCallback = AddHealth
	elseif item.name == "ManaPotion" then
		item.UseCallback = AddMana
	else
		item.UseCallback = AddPower
	end
	
	item.itemImage = Game:CreateScreenMask(0, 0, "".. item.imagePath)
	item.itemImage:SetVisible(false)
	item.itemImage:SetZVal(0)
	AddNewItem(self, item)
end

--[[
The following functions are all to be used to modify the player in some way when the player uses an
item from the inventory.
--]]
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