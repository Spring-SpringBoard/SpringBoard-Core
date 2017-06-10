AddRectState = AbstractEditingState:extends{}

function AddRectState:MousePress(x, y, button)
    if button == 1 then
        if self.addSecondPoint then
            return
        end
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            self.startX = coords[1]
            self.startZ = coords[3]
            self.endX = coords[1]
            self.endZ = coords[3]
            self.addSecondPoint = true
            return true
        end
    elseif button == 3 then
        SB.stateManager:SetState(DefaultState())
    end
end

function AddRectState:MouseMove(x, y, dx, dy, button)
    if not self.addSecondPoint then
        return
    end

    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        self.endX = coords[1]
        self.endZ = coords[3]
    end
end

function AddRectState:MouseRelease(x, y, button)
    if not self.addSecondPoint then
        return
    end

    if button ~= 1 then
        self.endX = nil
        self.endZ = nil
        return
    end
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        self.endX = coords[1]
        self.endZ = coords[3]
    end
    if self.endX == nil or self.endZ == nil then
        return
    end

    local cmd = AddAreaCommand(self.startX, self.startZ, self.endX, self.endZ)
    SB.commandManager:execute(cmd)

    SB.stateManager:SetState(DefaultState())
end

function AddRectState:DrawWorld()
    gl.PushMatrix()
    gl.Color(0, 1, 0, 0.2)
    if self.addSecondPoint then
        SB.view:drawRect(self.startX, self.startZ, self.endX, self.endZ)
    end
    gl.PopMatrix()
end
