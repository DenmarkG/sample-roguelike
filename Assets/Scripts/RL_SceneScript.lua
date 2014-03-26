-- new script file
function OnBeforeSceneLoaded(self)
	--get the current platform
	G.isWindows = (Application:GetPlatformName() == "WIN32DX9" or Application:GetPlatformName() == "WIN32DX11")
	
end

function OnAfterSceneLoaded(self)
	G.player = Game:GetEntity("Player")
end