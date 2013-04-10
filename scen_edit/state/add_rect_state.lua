AddRectState = AbstractState:extends{}

function AddRectState:init()
    self.addSecondPoint = false
end

function AddRectState:enterState()
    SCEN_EDIT.view.selected = nil
end

function AddRectState:leaveState()
end

function AddRectState:MousePress(x, y, button)
    if button == 1 then
        if not self.addSecondPoint then
            local result, coords = Spring.TraceScreenRay(x, y, true)
            if result == "ground" then
                self.startX = coords[1]
                self.startZ = coords[3]
                self.endX = coords[1]
                self.endZ = coords[3]
                self.addSecondPoint = true
                return true
            end
        end
    elseif button == 3 then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function AddRectState:MouseMove(x, y, dx, dy, button)
    if self.addSecondPoint then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            self.endX = coords[1]
            self.endZ = coords[3]
        end
    end
end

function AddRectState:MouseRelease(x, y, button)
    if self.addSecondPoint then
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
        SCEN_EDIT.commandManager:execute(cmd)

        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function AddRectState:KeyPress(key, mods, isRepeat, label, unicode)
end

function AddRectState:DrawWorld()
    gl.PushMatrix()
    gl.Color(0, 1, 0, 0.2)
    if self.addSecondPoint then
        SCEN_EDIT.view:drawRect(self.startX, self.startZ, self.endX, self.endZ)
    end
    gl.PopMatrix()
end
