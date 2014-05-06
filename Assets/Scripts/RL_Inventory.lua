-- new script file
function OnAfterSceneLoaded(self)
	self.inventory = {}
	self.itemsCollected = 0
	self.AddItem = AddNewItem
end

function AddNewItem(self, newItem)
	self.inventory[self.itemsCollected + 1] = newItem
end