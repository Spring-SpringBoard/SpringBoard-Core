TerrainSetState = AbstractHeightmapEditingState:extends{}

function TerrainSetState:GetCommand(x, z, strength)
    return TerrainLevelCommand({
        x = x + self.size/2,
		z = z + self.size/2,
        size = self.size,
        shapeName = self.patternTexture,
        rotation = self.rotation,
        height = self.height,

        strength = strength,
    })
end

function TerrainSetState:MousePress(x, y, button)
    if button == 3 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            self.height = coords[2]
            self.editorView:Set("height", self.height)
        end
    else
        return self:super("MousePress", x, y, button)
    end
end


--gl.Color(0, 0.5, 0.5, 0.4)
