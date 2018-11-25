ResizeAreaState = AbstractState:extends{}

function ResizeAreaState:init(areaID, resx, resz)
    AbstractState.init(self)

    self.areaID = areaID
    self.resx, self.resz = resx, resz

    if self.resx ~= 0 and self.resz == 0 then
        SB.SetMouseCursor("resize-x")
    elseif self.resx == 0 and self.resz ~= 0 then
        SB.SetMouseCursor("resize-y")
    elseif self.resx * self.resz < 0 then
        SB.SetMouseCursor("resize-x-y-0")
    else
        SB.SetMouseCursor("resize-x-y-1")
    end
    local area = SB.model.areaManager:getArea(self.areaID)
    self.x1, self.z1, self.x2, self.z2 = unpack(area)
    self.areaView = AreaView(self.areaID)
end

function ResizeAreaState:MouseMove(mx, my, ...)
    local result, coords = Spring.TraceScreenRay(mx, my, true)
    if result == "ground" then
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

function ResizeAreaState:MouseRelease(...)
    local area = SB.model.areaManager:getArea(self.areaID)
    local cmd = SetObjectParamCommand(areaBridge.name, self.areaID, {
        pos = { x = (self.x1 + self.x2)/2, y = 0, z = (self.z1 + self.z2)/2},
        size = { x = math.abs(self.x1 - self.x2), y = 0, z = math.abs(self.z1 - self.z2)},
    })
    SB.commandManager:execute(cmd)
    SB.stateManager:SetState(DefaultState())
end

function ResizeAreaState:DrawWorld()
    self.areaView:_Draw(self.x1, self.z1, self.x2, self.z2)
end
