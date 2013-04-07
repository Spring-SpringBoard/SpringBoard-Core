DragAreaState = AbstractState:extends{}
Spring.AssignMouseCursor('drag', 'drag', false)

function DragAreaState:init(areaId, startDiffX, startDiffZ)
    self.areaId = areaId
    self.startDiffX = startDiffX
    self.startDiffZ = startDiffZ
    self.dx = 0
    self.dz = 0
    self.areaView = AreaView(self.areaId)
    SCEN_EDIT.SetMouseCursor("drag")
end

function DragAreaState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local area = SCEN_EDIT.model.areaManager:getArea(self.areaId)
        local x1, z1, x2, z2 = unpack(area)
        self.dx = coords[1] + self.startDiffX - x1
        self.dz = coords[3] + self.startDiffZ - z1
    end
end

function DragAreaState:MouseRelease(x, y, button)
    local x1, z1, x2, z2 = unpack(SCEN_EDIT.model.areaManager:getArea(self.areaId))
    local cmd = MoveAreaCommand(self.areaId, self.dx + x1, self.dz + z1)
    SCEN_EDIT.commandManager:execute(cmd)
    SCEN_EDIT.stateManager:SetState(DefaultState())
end

function DragAreaState:DrawWorld()
    Spring.SetMouseCursor("drag")
    local x1, z1, x2, z2 = unpack(SCEN_EDIT.model.areaManager:getArea(self.areaId))
    self.areaView:_Draw(x1 + self.dx, z1 + self.dz, x2 + self.dx, z2 + self.dz)
end
