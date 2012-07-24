ResizeAreaCommand = UndoableCommand:extends{}
ResizeAreaCommand.className = "ResizeAreaCommand"

function ResizeAreaCommand:init(areaId, x1, z1, x2, z2)
    self.className = "ResizeAreaCommand"
    self.areaId = areaId
    self.x1, self.z1, self.x2, self.z2 = x1, z1, x2, z2
end

function ResizeAreaCommand:execute()
    self.oldArea = SCEN_EDIT.model.areaManager:getArea(self.areaId)

    SCEN_EDIT.model.areaManager:setArea(self.areaId, {
        self.x1, self.z1, self.x2, self.z2,
    })
end

function ResizeAreaCommand:unexecute()
    SCEN_EDIT.model.areaManager:setArea(self.areaId, self.oldArea)
end
