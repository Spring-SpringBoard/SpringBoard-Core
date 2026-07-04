SetHeightmapBrushCommand = NativeCommand:extends{}
SetHeightmapBrushCommand.className = "SetHeightmapBrushCommand"

-- TODO: make this save it only for one player
function SetHeightmapBrushCommand:init(greyscale)
    self.greyscale = greyscale
end
