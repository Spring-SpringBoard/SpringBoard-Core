SetHeightmapBrushCommand = AbstractCommand:extends{}
SetHeightmapBrushCommand.className = "SetHeightmapBrushCommand"

-- TODO: make this save it only for one player
function SetHeightmapBrushCommand:init(greyscale)
    self.className = "SetHeightmapBrushCommand"
    self.greyscale = greyscale
end

function SetHeightmapBrushCommand:execute()
    SCEN_EDIT.greyscale = self.greyscale
end