--[[
Author: Denmark Gibbs
This script handles:
	--What to do when a player collects a gem (enters a gem trigger)
	
Should be attached to a Trigger in the scene with the Gem model as a child of the trigger
]]--

function OnAfterSceneLoaded(self)	
	--save the sound path for when the gem is picked up
	self.GemSoundPath = "Sounds/RL_GemSound.mp3"
end

function OnObjectEnter(self, otherObj)
	if (otherObj:GetKey() == "Player") then
		--collect the gem
		otherObj:AddGem()
		
		--play the pickup sound
		local pickupSound = Fmod:CreateSound(self:GetPosition(), self.GemSoundPath, false)
		if pickupSound ~= nil then
			pickupSound:Play()
		end
		
		--hide the gem
		Deactivate(self)
	end
end

function OnBeforeSceneUnloaded(self)
	Game:DeleteAllUnrefScreenMasks()
end

--This funcion deactivates the trigger and hides its children
function Deactivate(self)
	self:SetEnabled(false)
	
	for i = 0, self:GetNumChildren(), 1 do
		local entity = self:GetChild(i)
		if entity ~= nil then
			entity:SetVisible(false)
		end
	end
end