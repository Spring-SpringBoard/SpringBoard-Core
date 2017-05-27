RemoveAreaCommand = Command:extends{}
RemoveAreaCommand.className = "RemoveAreaCommand"

function RemoveAreaCommand:init(areaId)
    self.className = "RemoveAreaCommand"
    self.areaId = areaId
end

function RemoveAreaCommand:execute()
    self.area = SB.model.areaManager:getArea(self.areaId)
    SB.model.areaManager:removeArea(self.areaId)
end

function RemoveAreaCommand:unexecute()
    self.areaId = SB.model.areaManager:addArea(self.area, self.areaId)
end
