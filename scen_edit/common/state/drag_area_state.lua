DragAreaState = AbstractState:extends{}

function DragAreaState:init(areaId, startDiffX, startDiffZ)
    self.areaId = areaId
    self.startDiffX = startDiffX
    self.startDiffZ = startDiffZ
    self.dx = 0
    self.dz = 0
end

function DragAreaState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y)
    if result == "ground" then
        local area = SCEN_EDIT.model.areaManager:getArea(self.areaId)
        local x1, z1, x2, z2 = unpack(area)
        self.dx = coords[1] + self.startDiffX - x1
        self.dz = coords[3] + self.startDiffZ - z1
    end
end

function DragAreaState:MouseRelease(x, y, button)
    SCEN_EDIT.view.areaViews[self.areaId].dx = nil
    SCEN_EDIT.view.areaViews[self.areaId].dz = nil
    local x1, z1, x2, z2 = unpack(SCEN_EDIT.model.areaManager:getArea(self.areaId))
    local cmd = MoveAreaCommand(self.areaId, self.dx + x1, self.dz + z1)
    SCEN_EDIT.commandManager:execute(cmd)
    SCEN_EDIT.stateManager:SetState(DefaultState)
end

function DragAreaState:DrawWorld()
    gl.PushMatrix()
    gl.Color(0.1, 1, 0.1, 0.4)
    local x1, z1, x2, z2 = unpack(SCEN_EDIT.model.areaManager:getArea(self.areaId))
    SCEN_EDIT.view:drawRect(x1 + self.dx, z1 + self.dz, x2 + self.dx, z2 + self.dz)
    gl.PopMatrix()
end
