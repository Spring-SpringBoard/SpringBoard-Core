RemoveAreaCommand = Command:extends{}
RemoveAreaCommand.className = "RemoveAreaCommand"

function RemoveAreaCommand:init(areaID)
    self.className = "RemoveAreaCommand"
    self.areaID = areaID
end

function RemoveAreaCommand:execute()
    self.area = SB.model.areaManager:getArea(self.areaID)
    SB.model.areaManager:removeArea(self.areaID)
end

function RemoveAreaCommand:unexecute()
    self.areaID = SB.model.areaManager:addArea(self.area, self.areaID)
end
