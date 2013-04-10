AddUnitState = AbstractState:extends{}

function AddUnitState:init(unitDef, teamId, unitImages)
    self.unitDef = unitDef
    self.teamId = teamId
    self.unitImages = unitImages
    self.x, self.y, self.z = 0, 0, 0
    self.angle = 0
end

function AddUnitState:enterState()
end

function AddUnitState:leaveState()
end

function AddUnitState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            self.x, self.y, self.z = unpack(coords)
            return true
        end
    elseif button == 3 then
        SCEN_EDIT.stateManager:SetState(DefaultState())
        self.unitImages:SelectItem(0)
    end
end

function AddUnitState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local dx = coords[1] - self.x
        local dz = coords[3] - self.z

        local len = math.sqrt(dx * dx + dz * dz)
        if len > 10 then
            self.angle = math.atan2(dx / len, dz / len) / math.pi * 180
        end
    end
end

function AddUnitState:MouseRelease(x, y, button)
    local cmd = AddUnitCommand(self.unitDef, self.x, self.y, self.z, self.teamId, self.angle)
    SCEN_EDIT.commandManager:execute(cmd)
    self.x, self.y, self.z = 0, 0, 0
    self.angle = 0
    return true
end

function AddUnitState:KeyPress(key, mods, isRepeat, label, unicode)
end

function AddUnitState:DrawWorld()
    local x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local dirX, dirY, dirZ = Spring.GetCameraDirection()
        local drawX, drawY, drawZ = unpack(coords)

        gl.PushMatrix()
        if self.x ~= 0 or self.y ~= 0 or self.z ~= 0 then
            gl.Translate(self.x, self.y, self.z)
            gl.Rotate(self.angle, 0, 1, 0)
        else
            gl.Translate(drawX, drawY, drawZ)
        end
        gl.Color(1, 1, 1, 0.8)
        gl.UnitShape(self.unitDef, self.teamId)
        gl.PopMatrix()            
    end
end
