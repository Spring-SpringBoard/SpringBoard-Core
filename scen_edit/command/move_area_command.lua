MoveAreaCommand = Command:extends{}
MoveAreaCommand.className = "MoveAreaCommand"

function MoveAreaCommand:init(areaId, newX, newZ)
    self.className = "MoveAreaCommand"
    self.areaId = areaId
    self.newX = newX
    self.newZ = newZ
end

function MoveAreaCommand:execute()
    local area = SB.model.areaManager:getArea(self.areaId)
    self.deltaX = self.newX - area[1]
    self.deltaZ = self.newZ - area[2] 

    SB.model.areaManager:setArea(self.areaId, {
        area[1] + self.deltaX,
        area[2] + self.deltaZ,
        area[3] + self.deltaX,
        area[4] + self.deltaZ,
    })
end

function MoveAreaCommand:unexecute()
    local area = SB.model.areaManager:getArea(self.areaId)

    SB.model.areaManager:setArea(self.areaId, {
        area[1] - self.deltaX,
        area[2] - self.deltaZ,
        area[3] - self.deltaX,
        area[4] - self.deltaZ,
    })
end
