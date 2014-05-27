function OnCreate(self)
	self.testCount = 0
end

function OnAfterSceneLoaded(self)
	if G.currentLevel > 1 then
		LoadItems(self)
	end
	
	if self.inventory == nil then
		self.inventory = {}
		self.maxItems = 8
		self.itemCount = 0
	end	
	
	self.gemsCollected = 0
	self.inventoryIsVisible = false
	
	--positioning varibles for display
	self.xSize = G.w / self.maxItems
	self.vertStartPos = G.h * 3 / 4

	self.AddItem = AddNewItem
	self.AddGem = AddNewGem
	self.ToggleInventory = InventoryToggled
	self.InventoryItemClicked = ItemClicked
	self.SaveInventory = SaveItems
	self.LoadInventory = LoadItems
end

function InventoryToggled(self)
	if not self.inventoryIsVisible then
		-- Debug:PrintLine(""..table.getn(self.inventory) )
		if self.itemCount > 0 then
			for i = 1, table.getn(self.inventory), 1 do
				local currentItem = self.inventory[i]
				-- Debug:PrintAt(10, G.fontSize * i, ""..currentItem.name, Vision.V_RGBA_GREEN, G.fontPath)
				currentItem.itemImage:SetVisible(true)
				currentItem.itemImage:SetBlending(Vision.BLEND_ALPHA)
				currentItem.itemImage:SetTargetSize(self.xSize, self.xSize)
				currentItem.itemImage:SetPos( (i-1) * self.xSize, self.vertStartPos)
			end
			
			self.inventoryIsVisible = true
		end
	else
		if self.itemCount > 0 then
			for i = 1, table.getn(self.inventory), 1 do
				local currentItem = self.inventory[i]
				currentItem.itemImage:SetVisible(false)
				-- currentItem.itemImage:SetBlending(Vision.BLEND_ALPHA)
			end
			
			self.inventoryIsVisible = false
		end
	end
end

function ItemClicked(self, xPos, yPos)
		if self.inventoryIsVisible then
			local yUpperBound = self.vertStartPos + self.xSize
			local ylowerBound = self.vertStartPos 
			
			if yPos < yUpperBound and yPos > ylowerBound then
				local numElements = self.itemCount
				local xUpperBound = self.xSize * numElements
				if xPos < xUpperBound then
					
					local xLowerBound = 0
					while xLowerBound <= xUpperBound do
					
						local middle = math.floor( (xUpperBound + xLowerBound) / 2)
						
						if xPos >= middle and xPos < middle + self.xSize then
							local index = math.floor(xPos / self.xSize)
							local item = self.inventory[index + 1]
							item:UseCallback(self)
							item.itemImage:SetVisible(false)
							if self.itemCount == 1 then
								self.inventory = {}
								self.itemCount = 0
							else
								table.remove(self.inventory, index + 1)
								self.ToggleInventory(self)
								self.itemCount = self.itemCount - 1
							end
							
							return true
						elseif xPos < middle then
							xUpperBound = middle
						elseif xPos >= middle then
							xLowerBound = middle
						end
					end
				end
			end
			
			return false
		end
	end

function AddNewGem(self)
	self.gemsCollected = self.gemsCollected + 1
end

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
			Debug:PrintLine(""..newItem.name.." "..newItem.value)
		else
			self.inventory[1] = newItem
			Debug:PrintLine(""..newItem.name.." "..newItem.value)
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

function AddHealth(self, character)
	character:ModifyHealth(self.value)
end

function AddMana(self, character)
	character:ModifyMana(self.value)
end

function AddPower(self, character)
	character:ModifyPower(self.value)
end