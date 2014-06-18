--[[
Author: Denmark Gibbs
This script handles:
	--What to do when a player collects a gem (enters a gem trigger)
	
Should be attached to a Trigger in the scene with the Gem model as a child of the trigger
--]]


--this callback function is invoked automatically once the scene has been loaded
function OnAfterSceneLoaded(self)	
	--save the sound path for when the gem is picked up
	self.GemSoundPath = "Sounds/RL_GemSound.mp3"
	
	--get the actual gem model that is a child of this trigger
	self.gemModel = self:GetChild("GemModel")
	
	--set up the animation
	if self.gemModel ~= nil then
		--add the animation component to the model
		self.gemModel.gemAnimation = self.gemModel:AddAnimation("GemAnimation")
		--play the animation
		self.gemModel.gemAnimation:Play("GemSpin", true)
	end
end

--This callback function is called whenever an object (otherObj) enters the trigger that this script is attached to.
function OnObjectEnter(self, otherObj)
	--only proceed if the other object was the player
	if (otherObj:GetKey() == "Player") then
		--Call the AddGem function on the player
		otherObj:AddGem()
		
		--get and play the pickup sound if it exists
		local pickupSound = Fmod:CreateSound(self:GetPosition(), self.GemSoundPath, false)
		if pickupSound ~= nil then
			pickupSound:Play()
		end
		
		--call the Deactivate function to hide the gem and make sure the trigger can't be hit again. 
		Deactivate(self)
	end
end

--this callback is called automatically before the scene is unloaded
function OnBeforeSceneUnloaded(self)
	--delete any screen masks that have been created
	Game:DeleteAllUnrefScreenMasks()
end

--This funcion deactivates the trigger and hides its children
function Deactivate(self)
	--deactivate the trigger
	--this prevents the gem from being collected twice
	self:SetEnabled(false)
	
	--loop through all of the children of this trigger in the scene. 
	for i = 0, self:GetNumChildren(), 1 do
		--cache the currently selected item
		local entity = self:GetChild(i)
		--if the entity is not nil, hide it
		if entity ~= nil then
			entity:SetVisible(false)
		end
	end
end