ResizeAreaState = AbstractState:extends{}

function ResizeAreaState:init(areaId, resx, resz)
    self.areaId = areaId
    self.resx, self.resz = resx, resz
    local area = SCEN_EDIT.model.areaManager:getArea(self.areaId)
    self.x1, self.z1, self.x2, self.z2 = unpack(area)
    self.areaView = AreaView(self.areaId)
end

function ResizeAreaState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local area = SCEN_EDIT.model.areaManager:getArea(self.areaId)
        if self.resx == -1 then
            self.x1 = coords[1] + drag_diff_x 
        elseif self.resx == 1 then
            self.x2 = coords[1] + drag_diff_x 
        end
        if self.resz == -1 then
            self.z1 = coords[3] + drag_diff_z 
        elseif self.resz == 1 then
            self.z2 = coords[3] + drag_diff_z 
        end
    end
end

function ResizeAreaState:MouseRelease(x, y, button)
    local area = SCEN_EDIT.model.areaManager:getArea(self.areaId)
    if self.x1 > self.x2 then
        self.x1, self.x2 = self.x2, self.x1
    end
    if self.z1 > self.z2 then
        self.z1, self.z2 = self.z2, self.z1
    end
    local cmd = ResizeAreaCommand(self.areaId, self.x1, self.z1, self.x2, self.z2)
    SCEN_EDIT.commandManager:execute(cmd)
    SCEN_EDIT.stateManager:SetState(DefaultState())
end

function ResizeAreaState:DrawWorld()
    self.areaView:_Draw(self.x1, self.z1, self.x2, self.z2)
end
