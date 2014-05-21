function OnCreate(self)
	self.testCount = 0
	self.AddTwo = AddTwoMore
end

function OnAfterSceneLoaded(self)
	self.inventory = {}
	self.maxItems = 8
	self.itemCount = 0
	
	self.gemsCollected = 0
	self.inventoryIsVisible = false
	
	self.xSize = G.w / self.maxItems
	
	--positioning varibles for display
	self.vertStartPos = G.h * 3 / 4

	self.AddItem = AddNewItem
	self.AddGem = AddNewGem
	self.ToggleInventory = InventoryToggled
	self.InventoryItemClicked = ItemClicked
	-- self.ReloadItem = ReloadExistingItem
end

function AddTwoMore(self)
	self.testCount = self.testCount + 2
	Debug:PrintLine(""..self.testCount)
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
			Debug:PrintLine("item added")
		else
			self.inventory[1] = newItem
			-- Debug:PrintLine("item added")
		end
		
		self.itemCount = self.itemCount + 1
	end
	
	-- Debug:PrintLine(""..self.itemCount)
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