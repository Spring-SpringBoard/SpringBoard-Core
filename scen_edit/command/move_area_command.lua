MoveAreaCommand = Command:extends{}
MoveAreaCommand.className = "MoveAreaCommand"

function MoveAreaCommand:init(areaID, newX, newZ)
    self.className = "MoveAreaCommand"
    self.areaID = areaID
    self.newX = newX
    self.newZ = newZ
end

function MoveAreaCommand:execute()
    local area = SB.model.areaManager:getArea(self.areaID)
    self.deltaX = self.newX - area[1]
    self.deltaZ = self.newZ - area[2]

    SB.model.areaManager:setArea(self.areaID, {
        area[1] + self.deltaX,
        area[2] + self.deltaZ,
        area[3] + self.deltaX,
        area[4] + self.deltaZ,
    })
end

function MoveAreaCommand:unexecute()
    local area = SB.model.areaManager:getArea(self.areaID)

    SB.model.areaManager:setArea(self.areaID, {
        area[1] - self.deltaX,
        area[2] - self.deltaZ,
        area[3] - self.deltaX,
        area[4] - self.deltaZ,
    })
end
