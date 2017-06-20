ResizeAreaCommand = Command:extends{}
ResizeAreaCommand.className = "ResizeAreaCommand"

function ResizeAreaCommand:init(areaID, x1, z1, x2, z2)
    self.className = "ResizeAreaCommand"
    self.areaID = areaID
    self.x1, self.z1, self.x2, self.z2 = x1, z1, x2, z2
end

function ResizeAreaCommand:execute()
    self.oldArea = SB.model.areaManager:getArea(self.areaID)

    SB.model.areaManager:setArea(self.areaID, {
        self.x1, self.z1, self.x2, self.z2,
    })
end

function ResizeAreaCommand:unexecute()
    SB.model.areaManager:setArea(self.areaID, self.oldArea)
end
