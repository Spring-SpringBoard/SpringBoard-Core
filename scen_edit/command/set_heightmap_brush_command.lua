SetHeightmapBrushCommand = Command:extends{}
SetHeightmapBrushCommand.className = "SetHeightmapBrushCommand"

-- TODO: make this save it only for one player
function SetHeightmapBrushCommand:init(greyscale)
    self.className = "SetHeightmapBrushCommand"
    self.greyscale = greyscale
end

function SetHeightmapBrushCommand:execute()
    SB.model.terrainManager:addShape(self.greyscale.name, self.greyscale)
end