ExportMetalSpotConfigCommand = Command:extends{}
ExportMetalSpotConfigCommand.className = "ExportMetalSpotConfigCommand"

function ExportMetalSpotConfigCommand:init(path)
    self.path = path
    if Path.GetExt(self.path) ~= ".lua" then
        self.path = self.path .. ".lua"
    end
end

function ExportMetalSpotConfigCommand:GetMetalSpots()
	local tbl = {}
	local spots = SB.model.mexManager:getAllMexes()
    for mexID, params in pairs(spots) do
		local x, z, metal = params.x, params.z, params.metal
		table.insert(tbl, {x = x, z = z, metal = metal})
		if params.xmirror and params.zmirror then
			x, z = Game.mapSizeX-x, Game.mapSizeZ-z
			table.insert(tbl, {x = x, z = z, metal = metal})
		elseif params.xmirror then
			x = Game.mapSizeX-x
			table.insert(tbl, {x = x, z = z, metal = metal})
		elseif params.zmirror then
			z = Game.mapSizeZ-z
			table.insert(tbl, {x = x, z = z, metal = metal})	
		end
	end
    return tbl
end

function ExportMetalSpotConfigCommand:execute()
    local file = assert(io.open(self.path, "w"))
    file:write("local allspots = ")
    file:write(table.show(self:GetMetalSpots()):sub(#"return "))
    file:write("\nreturn {spots = allspots}")
    file:close()
end
