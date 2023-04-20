ExportStartBoxConfigCommand = Command:extends{}
ExportStartBoxConfigCommand.className = "ExportStartBoxConfigCommand"

function ExportStartBoxConfigCommand:init(path)
    self.path = path
    if Path.GetExt(self.path) ~= ".lua" then
        self.path = self.path .. ".lua"
    end
end

function ExportStartBoxConfigCommand:GetStartBoxes()
	local teamList = {}
	-- teamList.boxes, teamList.x, teamList.z, teamList.name, teamList.short = {}, {}, {}, {}, {}
	local boxes = SB.model.startboxManager:getAllStartBoxes()
    for boxID, _ in pairs(boxes) do
		local teamID = SB.model.startboxManager:getTeam(boxID)
		local team = SB.model.teamManager:getTeam(teamID)
		local maybePos = SB.model.startboxManager:getBoxPos(boxID)
		if team.startPos then
			maybePos.x, maybePos.z = team.startPos.x, team.startPos.z
		end
		if not team.short then
			team.short = team.name
		end
		if not teamList[teamID] then
			teamList[teamID] = {name = team.name, short = team.short, x = maybePos.x, z = maybePos.z, boxes = {}}
		end
		table.insert(teamList[teamID].boxes, boxID)
	end
    return teamList
end

function ExportStartBoxConfigCommand:execute()
    local file = assert(io.open(self.path, "w"))
	local teamList = self:GetStartBoxes()
    file:write("local allboxes = {\n")
	for ID, team in pairs(teamList) do
		file:write("\t["..ID.."] = {\n\t\tstartpoints = {\n\t\t\t {")
		file:write(teamList[ID].x..","..teamList[ID].z.."}\n\t\t},\n\t\t")
		file:write("boxes = {\n\t\t\t")
		for _, boxID in pairs(teamList[ID].boxes) do
			local tbl = SB.model.startboxManager:getBox(boxID)
			file:write(table.show(tbl):sub(#"return ")..",")
		end
		file:write("\n\t\t},\n\t\tnameLong = \""..teamList[ID].name.."\",")
		file:write("\n\t\tnameShort = \""..teamList[ID].short.."\",\n\t},\n")
	end
	file:write("\n}\n\n")
    file:write("return allboxes")
    file:close()
end