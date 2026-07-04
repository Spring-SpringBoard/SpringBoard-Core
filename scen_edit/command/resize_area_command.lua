ResizeAreaCommand = NativeCommand:extends{}
ResizeAreaCommand.className = "ResizeAreaCommand"

function ResizeAreaCommand:init(areaID, x1, z1, x2, z2)
    self.areaID = areaID
    self.x1, self.z1, self.x2, self.z2 = x1, z1, x2, z2
end
