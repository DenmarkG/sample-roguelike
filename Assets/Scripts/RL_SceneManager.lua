-- new script file


function OnBeforeSceneLoaded(self)
	--get the current platform
	G.isWindows = (Application:GetPlatformName() == "WIN32DX9" or Application:GetPlatformName() == "WIN32DX11")
	
	--set the font path
	G.fontPath = "Fonts/Harrington.fnt"
	G.fontSize = 32
	
	--Room0 = "Meshes/LevelBlocks/SM_Room_Type-02.vmesh"
	
	--RoomSize = 768
	--GenerateRooms(self)
end

function OnAfterSceneLoaded(self)
	FindWaypoints(self)
	
	--get the screen size
	G.w, G.h = Screen:GetViewportSize()
	
	--cache the player for easy access
	G.player = Game:GetEntity("Player")
end

function OnBeforeSceneUnloaded(self)
	--delete the screen masks
	Game:DeleteAllUnrefScreenMasks()
end

-- function GenerateRooms(self)
	-- Debug:PrintLine("Rooms Generated")
	-- Game:CreateEntity(Vision.hkvVec3(0,0,0), "VisBaseEntity_cl", Room0, "StartRoom")
	-- Game:InstantiatePrefab(Vision.hkvVec3(0,0,0), Room0)
	-- local mesh = Game:CreateStaticMeshInstance(Vision.hkvVec3(0,0,0), Room0, true, "StartRoom")
	-- mesh:SetVisibleBitmask(Vision.VBitmask("0xFF") )
-- end

function FindWaypoints(self)
	G.waypoints = {}
	local parent = Game:GetEntity("WaypointParent")
	
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