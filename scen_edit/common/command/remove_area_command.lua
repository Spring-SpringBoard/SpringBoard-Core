RemoveAreaCommand = UndoableCommand:extends{}
RemoveAreaCommand.className = "RemoveAreaCommand"

function RemoveAreaCommand:init(areaId)
    self.className = "RemoveAreaCommand"
    self.areaId = areaId
end

function RemoveAreaCommand:execute()
    self.area = SCEN_EDIT.model.areaManager:getArea(self.areaId)
    SCEN_EDIT.model.areaManager:removeArea(self.areaId)
end

function RemoveAreaCommand:unexecute()
    self.areaId = SCEN_EDIT.model.areaManager:addArea(self.area, self.areaId)
end
