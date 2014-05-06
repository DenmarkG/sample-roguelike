-- new script file
function OnAfterSceneLoaded(self)
	self.inventory = {}
	self.itemCount = 0
	self.AddItem = AddNewItem
	
	self.ShowInventory = function(self)
		-- Debug:PrintLine(""..table.getn(self.inventory) )
		if self.itemCount > 0 then
			for i = 0, table.getn(self.inventory), 1 do
				local currentItem = self.inventory[i]
				Debug:PrintAt(10, (G.fontSize * i) + G.fontSize, ""..currentItem.name, Vision.V_RGBA_WHITE, G.fontPath)
			end
		end
		
		--Debug:PrintAt(10, 64, "Look: MOUSE", Vision.V_RGBA_WHITE, G.fontPath)
		--Debug:PrintAt(10, 96, "Run: LEFT SHIFT", Vision.V_RGBA_WHITE, G.fontPath)
		--Debug:PrintAt(10, 128, "Fire: LEFT MOUSE BUTTON", Vision.V_RGBA_WHITE, G.fontPath)
		--Debug:PrintAt(10, 160, "Reload: R", Vision.V_RGBA_WHITE, G.fontPath)
		--Debug:PrintAt(10, 192, "Jump: SPACEBAR", Vision.V_RGBA_WHITE, G.fontPath)
		--Debug:PrintAt(10, 224, "Invert Y: I", Vision.V_RGBA_WHITE, G.fontPath)
		--local inverted = self.invertY and "yes" or "No"
		--Debug:PrintAt(10, 256, "Inverted?: " .. inverted , Vision.V_RGBA_WHITE, G.fontPath)
	end
end

function AddNewItem(self, newItem)
	if self.itemCount > 0 then
		self.inventory[self.itemCount] = newItem
	else
		self.inventory[0] = newItem
	end
	
	self.itemCount = self.itemCount + 1
end