TerrainErodeState = AbstractHeightmapEditingState:extends{}

function TerrainErodeState:init(editorView)
    AbstractHeightmapEditingState.init(self, editorView)
    self.height = self.editorView.fields["height"].value
    self.applyDir = self.editorView.fields["applyDir"].value
end

local applyDirIDs = {
    ["Both"] = 0,
    ["Only Raise"] = 1,
    ["Only Lower"] = -1,
}
function TerrainErodeState:GetCommand(x, z, strength)
    local applyDirID = applyDirIDs[self.applyDir]
    return TerrainErosionCommand({
        x = x + self.size/2,
        z = z + self.size/2,
        size = self.size,
        shapeName = self.patternTexture,
        rotation = self.rotation,
        height = self.height,
        applyDirID = applyDirID,

        strength = strength,
    })
end

function TerrainErodeState:MousePress(mx, my, button)
    if button == 3 then
        local result, coords = Spring.TraceScreenRay(mx, my, true, false, false, true)
        if result == "ground"  then
            self.height = coords[2]
            self.editorView:Set("height", self.height)
        end
    else
        return self:super("MousePress", mx, my, button)
    end
end


--gl.Color(0, 0.5, 0.5, 0.4)
