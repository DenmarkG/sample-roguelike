-- new script file
function OnBeforeSceneLoaded(self)
	--get the current platform
	G.isWindows = (Application:GetPlatformName() == "WIN32DX9" or Application:GetPlatformName() == "WIN32DX11")
end

function OnAfterSceneLoaded(self)
	--get the screen size
	G.w, G.h = Screen:GetViewportSize()
	
	--cache the player for easy access
	G.player = Game:GetEntity("Player")
	
	--set the font path
	G.fontPath = "Fonts/RL_Gulim_Font.fnt"
	
	--set the gamestate
	G.gameOver = false
end

function OnBeforeSceneUnloaded(self)
	--delete the screen masks
	Game:DeleteAllUnrefScreenMasks()
end