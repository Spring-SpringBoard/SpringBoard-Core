RectangleSelectState = AbstractState:extends{}

function RectangleSelectState:init(startScreenX, startScreenZ)
    self.startScreenX = startScreenX
    self.startScreenZ = startScreenZ
    self.endScreenX = nil
    self.endScreenZ = nil
end

function RectangleSelectState:enterState()
    SCEN_EDIT.view.selected = nil
end

function RectangleSelectState:leaveState()
end

function RectangleSelectState:MousePress(x, y, button)
end

function RectangleSelectState:MouseMove(x, y, dx, dy, button)
    self.endScreenX = x
    self.endScreenZ = y
    --[[if self.addSecondPoint then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            self.endX = coords[1]
            self.endZ = coords[3]
        end
    end--]]
--    return true
end

function RectangleSelectState:MouseRelease(x, y, button)
    if self.endScreenX and self.endScreenZ then
        local result1, coords1 = Spring.TraceScreenRay(self.startScreenX, self.startScreenZ, true)
        local result2, coords2 = Spring.TraceScreenRay(self.endScreenX, self.endScreenZ, true)
        if result1 == "ground" and result2 == "ground" then
            local x1, _, z1 = unpack(coords1)
            local x2, _, z2 = unpack(coords2)
            if x1 > x2 then
                x1, x2 = x2, x1
            end
            if z1 > z2 then
                z1, z2 = z2, z1
            end
            local unitIds = Spring.GetUnitsInRectangle(x1, z1, x2, z2)
            local featureIds = Spring.GetFeaturesInRectangle(x1, z1, x2, z2)
            if #unitIds > 0 then
                SCEN_EDIT.view.selectionManager:SelectUnits(unitIds)
            elseif #featureIds > 0 then
                SCEN_EDIT.view.selectionManager:SelectFeatures(featureIds)
            end
        end
    end
    SCEN_EDIT.stateManager:SetState(DefaultState())
end

function RectangleSelectState:KeyPress(key, mods, isRepeat, label, unicode)
end

function RectangleSelectState:DrawScreen()
    if self.endScreenX and self.endScreenZ then
        local x1, z1 = self.startScreenX, self.startScreenZ
        local x2, z2 = self.endScreenX, self.endScreenZ
        gl.BeginEnd(GL.LINE_LOOP,
            function()
                gl.Vertex(x1, z1)
                gl.Vertex(x1, z2)
                gl.Vertex(x2, z2)
                gl.Vertex(x2, z1)
                gl.Vertex(x1, z1)
            end
        )
    end
end
