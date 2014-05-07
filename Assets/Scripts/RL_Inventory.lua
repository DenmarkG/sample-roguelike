-- new script file
function OnAfterSceneLoaded(self)
	self.inventory = {}
	self.itemCount = 0
	self.maxItems = 8
	
	self.AddItem = AddNewItem
	
	self.isVisible = false
	
	self.ToggleInventory = function(self)
		if not self.isVisible then
			-- Debug:PrintLine(""..table.getn(self.inventory) )
			if self.itemCount > 0 then
				local xSize = G.w / self.maxItems
				
				for i = 0, table.getn(self.inventory), 1 do
					local currentItem = self.inventory[i]
					-- Debug:PrintAt(10, G.fontSize * i, ""..currentItem.name, Vision.V_RGBA_GREEN, G.fontPath)
					currentItem.itemImage:SetVisible(true)
					currentItem.itemImage:SetBlending(Vision.BLEND_ALPHA)
					currentItem.itemImage:SetTargetSize(xSize, xSize)
					currentItem.itemImage:SetPos(i * xSize, G.h * 3 / 4)
				end
				
				self.isVisible = true
			end
		else
			for i = 0, table.getn(self.inventory), 1 do
				local currentItem = self.inventory[i]
				currentItem.itemImage:SetVisible(false)
				-- currentItem.itemImage:SetBlending(Vision.BLEND_ALPHA)
			end
			
			self.isVisible = false
		end
	end
end

function AddNewItem(self, newItem)
	if not (self.itemCount >= self.maxItems) then
		if self.itemCount > 0 then
			self.inventory[self.itemCount] = newItem
		else
			self.inventory[0] = newItem
		end
		
		self.itemCount = self.itemCount + 1
	end
end