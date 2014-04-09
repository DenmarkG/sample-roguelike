-- new script file
function OnAfterSceneLoaded(self)
	self.inventory = {}
	self.inventory.itemsCollected = 0
	self.AddItem = AddNewItem
end

function AddNewItem(self)
	self.inventory.itemsCollected = self.inventory.itemsCollected + 1
end