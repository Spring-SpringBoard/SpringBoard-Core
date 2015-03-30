SetHeightmapBrushCommand = AbstractCommand:extends{}
SetHeightmapBrushCommand.className = "SetHeightmapBrushCommand"

-- TODO: make this save it only for one player
function SetHeightmapBrushCommand:init(greyscale)
    self.className = "SetHeightmapBrushCommand"
    self.greyscale = greyscale
end

function SetHeightmapBrushCommand:execute()
    if SCEN_EDIT.terrainManager == nil then
        SCEN_EDIT.terrainManager = TerrainManager()
    end
    SCEN_EDIT.terrainManager:addShape(self.greyscale.name, self.greyscale)
end