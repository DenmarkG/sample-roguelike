--[[
Author: Denmark Gibbs
This Script:
	managaes global variables for entites, screen information, and Touch Areas for mobile
	finds and stores locations of all waypoints for enemy AI
	keeps track of current game level

This should be attached to the Main Layer of each scene
]]--

--these global variables will keep track of the levels and won't be destroyed between levels.
G.currentLevel = 1
G.maxLevelCount = 2

--[[
this callback is called before the assets in the scene begin to load, and, since it is attached to  
the Main Layer, it is a good place to get information and set up global variables that other scripts will use
since it is guranteed to be called before any other OnBeforeSceneLoaded functions
--]]
function OnBeforeSceneLoaded(self)
	--get the current platform
	G.isWindows = (Application:GetPlatformName() == "WIN32DX9" or Application:GetPlatformName() == "WIN32DX11")
	
	--set the font path
	G.fontPath = "Fonts/Harrington.fnt"
	G.fontSize = 32
	
	--get the screen size
	G.w, G.h = Screen:GetViewportSize()
	
	--set up the appropriate help icon based on the platform
	if G.isWindows then
		G.helpButton = Game:CreateScreenMask(0, 0, "Textures/HelpButtons/RL_HelpButton_PC.tga")
	else
		G.helpButton = Game:CreateScreenMask(0, 0, "Textures/HelpButtons/RL_HelpButton_Touch.tga")
	end
	
	G.helpButtonPriority = -900
	
	--get the size of the help button, then move to the bottom left corner
	local helpX, helpY = G.helpButton:GetTextureSize()
	G.helpButton:SetPos( (G.w / 2) - helpX / 2, G.h - helpY) 
	G.helpButton:SetBlending(Vision.BLEND_ALPHA)
	G.helpTable = { (G.w / 2) - helpX / 2, G.h - helpY, (G.w / 2) + helpX / 2, G.h, G.helpButtonPriority, "new"}
	
	--when this is true, the game will draw the debug and AI info
	G.isAiDebugInfoOn = true
end

--called after the scene has loaded
function OnAfterSceneLoaded(self)
	--find the location of all the waypoints in the scene
	FindWaypoints(self)
	
	--enable debug drawing (for the HUD and the enemy vision cone)
	Debug:Enable(true)
	
	--cache the player and level manager for easy access by other scripts
	G.player = Game:GetEntity("Player")
	G.levelManager = Game:GetEntity("LevelManager")
	
	--setting up the mobile HUD
	if not G.isWindows then
		--set the values for the texture's position on screen (as a percentage)
		local yPercent = .75
		local xPercent_R = 0.8 --percentage of the screen to align objects to the right
		local textureSize = 64 --the texture size
		
		local buttonPriority = -150
		
		--the texture size times this value gives the total space the buttons will take up verticall and horizontally
		local buttonSpaceMultiplier = 1.5 
		
		--the button placement will be based on a square space in the lower right corner of the screen
		top = (G.h * yPercent) - (textureSize * 1.5) --the top edge of the space
		bottom = (G.h * yPercent) + (textureSize * 1.5) --the bottom edge of the space
		left = (G.w * xPercent_R) - (textureSize * 1.5) --the left edge of the space
		right = (G.w * xPercent_R) + (textureSize * 1.5) --the right edge of the space
		
		--[[
		for each button:
			create a screen mask
			set the blending to alpha, so it layers nicely over the scene
			create the table to correspond to the space it will take up on a touchscreen device
		--]]
		G.greenButton = Game:CreateScreenMask(left + textureSize, bottom - textureSize, "Textures/MobileHud/FPS_Button_Green_64.tga")
		G.greenButton:SetBlending(Vision.BLEND_ALPHA)
		G.greenTable = {left + textureSize, bottom - textureSize, right - textureSize, bottom, buttonPriority}
		
		G.redButton = Game:CreateScreenMask(right - textureSize, top + textureSize, "Textures/MobileHud/FPS_Button_Red_64.tga")
		G.redButton:SetBlending(Vision.BLEND_ALPHA)
		G.redTable = {right - textureSize, top + textureSize, right, bottom - textureSize, buttonPriority}
		
		G.yellowButton = Game:CreateScreenMask(left, top + textureSize, "Textures/MobileHud/FPS_Button_Yellow_64.tga")
		G.yellowButton:SetBlending(Vision.BLEND_ALPHA)
		G.yellowTable = {left, top + textureSize, left + textureSize, bottom - textureSize, buttonPriority}
		
		G.blueButton = Game:CreateScreenMask(left + textureSize, top, "Textures/MobileHud/FPS_Button_Blue_64.tga")
		G.blueButton:SetBlending(Vision.BLEND_ALPHA)
		G.blueTable = {left + textureSize, top, right - textureSize, top + textureSize, buttonPriority}
	end
end

--this callback is called automatically before the scene is unloaded
function OnBeforeSceneUnloaded(self)
	--delete the screen masks
	Game:DeleteAllUnrefScreenMasks()
end

--[[
This function finds all the waypoints in the scene that the enemies will use to patrol the space
--]]
function FindWaypoints(self)
	--create the global collection of waypoints
	G.waypoints = {}
	
	--all the waypoints are children of the way point parent
	local parent = Game:GetEntity("WaypointParent")
	
	
	--iterate through the children and add the waypoints to the global collection
	if parent ~= nil then
		local numChildren = parent:GetNumChildren()
		for i = 0, numChildren - 1, 1 do
			local entity = parent:GetChild(i)
			
			if entity ~= nil then
				if entity:GetKey() == "Waypoint" then 
					table.insert(G.waypoints, entity)
				end
			end
		end
	end
end