-- new script file

function OnAfterSceneLoaded()
	--
end

function OnExpose(self)
	--
end

function OnThink(self)
	--
end

function OnObjectEnter(self, otherObj)
	if otherObj:GetKey() == "Player" then
		otherObj:Collect(self)
	end
end

function OnBeforeSceneUnloaded(self)
	--
end 