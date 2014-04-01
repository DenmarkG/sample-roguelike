-- new script file
function OnAfterSceneLoaded(self)
	self.inventory = {}
	self.inventory.itemsCollected = 0
	self.Collect = CollectNewItem
end

function CollectNewItem(self)
	self.inventory.itemsCollected = self.inventory.itemsCollected + 1
end