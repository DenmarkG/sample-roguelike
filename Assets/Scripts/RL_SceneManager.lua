--[[
Author: Denmark Gibbs
This Script:
	managaes global variables for entites, screen information, and Touch Areas for mobile
	finds and stores locations of all waypoints for enemy AI
	keeps track of current game level

This should be attached to the Main Layer of each scene
]]--
G.currentLevel = 1
G.maxLevelCount = 2

function OnBeforeSceneLoaded(self)
	--get the current platform
	G.isWindows = (Application:GetPlatformName() == "WIN32DX9" or Application:GetPlatformName() == "WIN32DX11")
	
	--set the font path
	G.fontPath = "Fonts/Harrington.fnt"
	G.fontSize = 32
	
	--get the screen size
	G.w, G.h = Screen:GetViewportSize()
	
	if G.isWindows then
		G.helpButton = Game:CreateScreenMask(0, 0, "Textures/HelpButtons/RL_HelpButton_PC.tga")
	else
		G.helpButton = Game:CreateScreenMask(0, 0, "Textures/HelpButtons/RL_HelpButton_Touch.tga")
	end
	
	--get the size of the help button, then move to the bottom left corner
	local helpX, helpY = G.helpButton:GetTextureSize()
	G.helpButton:SetPos( (G.w / 2) - helpX / 2, G.h - helpY) 
	G.helpButton:SetBlending(Vision.BLEND_ALPHA)
	G.helpTable = { (G.w / 2) - helpX / 2, G.h - helpY, (G.w / 2) + helpX / 2, G.h, -900, "new"}
end

function OnAfterSceneLoaded(self)
	FindWaypoints(self)
	Debug:Enable(true)
	
	--cache the player for easy access
	G.player = Game:GetEntity("Player")
	G.levelManager = Game:GetEntity("LevelManager")
	
	--setting up the mobile HUD
	if not G.isWindows then
		--set the values for the texture's position on screen (as a percentage)
		local xPercent = .2
		local yPercent = .75

		local xPercent_R = 0.8 --percentage of the screen to align objects to the right
		x = 64 --the texture size
		
		--the button placement will be based on a square space in the lower right corner of the screen
		top = (G.h * yPercent) - (x * 1.5)
		bottom = (G.h * yPercent) + (x * 1.5)
		left = (G.w * xPercent_R) - (x * 1.5)
		right = (G.w * xPercent_R) + (x * 1.5)
		
		--setting up each of the buttons, and the space each corresponds to
		G.greenButton = Game:CreateScreenMask(left + x, bottom - x, "Textures/MobileHud/FPS_Button_Green_64.tga")
		G.greenButton:SetBlending(Vision.BLEND_ALPHA)
		G.greenTable = {left + x, bottom - x, right - x, bottom, -150}
		
		G.redButton = Game:CreateScreenMask(right - x, top + x, "Textures/MobileHud/FPS_Button_Red_64.tga")
		G.redButton:SetBlending(Vision.BLEND_ALPHA)
		G.redTable = {right - x, top + x, right, bottom - x, -150}
		
		G.yellowButton = Game:CreateScreenMask(left, top + x, "Textures/MobileHud/FPS_Button_Yellow_64.tga")
		G.yellowButton:SetBlending(Vision.BLEND_ALPHA)
		G.yellowTable = {left, top + x, left + x, bottom - x, -150}
		
		G.blueButton = Game:CreateScreenMask(left + x, top, "Textures/MobileHud/FPS_Button_Blue_64.tga")
		G.blueButton:SetBlending(Vision.BLEND_ALPHA)
		G.blueTable = {left + x, top, right - x, top + x, -150}
	end
end

function OnBeforeSceneUnloaded(self)
	--delete the screen masks
	Game:DeleteAllUnrefScreenMasks()
end

--[[
This function finds all the waypoints in the scene that the enemies will use to patrol the space
--]]
function FindWaypoints(self)
	G.waypoints = {}
	local parent = Game:GetEntity("WaypointParent")
	
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