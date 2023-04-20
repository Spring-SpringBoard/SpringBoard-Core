LoadZKMapConfigCommand = Command:extends{}
LoadZKMapConfigCommand.className = "LoadZKMapConfigCommand"

function LoadZKMapConfigCommand:init(ZKmapconfig)
    -- Since the introduction of the data packing/unpacking, is much more
    -- efficient passing tables than strings
    if ZKmapconfig then
        self.mapConfig = loadstring(ZKmapconfig)()
	else
		self.mapConfig = {}
		local boxID = 1
		local mapsideBoxes = "mapconfig/map_startboxes.lua"
		local mapsideMexes = "mapconfig/map_metal_layout.lua"
		if VFS.FileExists (mapsideBoxes) then
			self.mapConfig.teamList, self.mapConfig.boxes = {}, {}
			local boxConfig = VFS.Include(mapsideBoxes)
			for ID, boxdata in pairs(boxConfig) do
				local color = { r=math.random(), g=math.random(), b=math.random(), a=1}
				self.mapConfig.teamList[ID] = {id = ID, allyTeam = ID, color = color, name = boxdata.nameLong, short = (boxdata.nameShort or boxdata.nameLong), x = boxdata.startpoints[1][1], z = boxdata.startpoints[1][2], boxes = {}}
				for _, box in pairs(boxdata.boxes) do
					table.insert(self.mapConfig.teamList[ID].boxes, boxID)
					table.insert(self.mapConfig.boxes, box)
					boxID = boxID + 1
				end
			end
		end
		if VFS.FileExists (mapsideMexes) then
			self.mapConfig.mexes = VFS.Include(mapsideMexes).spots
		end
    end
end

function LoadZKMapConfigCommand:execute()
	--assert(self.mapConfig)
    local mexes = self.mapConfig.mexes or {}
	local boxes = self.mapConfig.boxes or {}
	local teamList = self.mapConfig.teamList or {}
    SB.delay(function()
    SB.delay(function()
        for mexID, mex in pairs(mexes) do
			SB.model.mexManager:addMex(mex)
        end
		for teamID, team in pairs(teamList) do
			for _, boxID in pairs(team.boxes) do
				local newBoxID = SB.model.startboxManager:addBox(boxes[boxID])
				SB.model.startboxManager:setTeam(newBoxID, teamID)
			end
			if not SB.model.teamManager:getTeam(teamID) then
				local cmd = AddTeamCommand(team.name, team.color, team.allyTeam, Spring.GetSideData(team.allyTeam))
				SB.commandManager:execute(cmd)
			end
			local cmd = UpdateTeamCommand(team)
			SB.commandManager:execute(cmd)
		end
    end)
    end)
end