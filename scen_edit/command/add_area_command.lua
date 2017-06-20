AddAreaCommand = Command:extends{}
AddAreaCommand.className = "AddAreaCommand"

function AddAreaCommand:init(x1, z1, x2, z2)
    self.className = "AddAreaCommand"
    self.x1 = x1
    self.x2 = x2
    self.z1 = z1
    self.z2 = z2
end

function AddAreaCommand:execute()
    if self.x1 < self.x2 then
        self.x1, self.x2 = self.x1, self.x2
    else
        self.x1, self.x2 = self.x2, self.x1
    end
    if self.z1 < self.z2 then
        self.z1, self.z2 = self.z1, self.z2
    else
        self.z1, self.z2 = self.z2, self.z1
    end
    local area = {self.x1, self.z1, self.x2, self.z2}
    self.areaID = SB.model.areaManager:addArea(area, self.areaID)
end

function AddAreaCommand:unexecute()
    SB.model.areaManager:removeArea(self.areaID)
end
