UndoableExampleCommand = Command:extends{}

local value = 0
function UndoableExampleCommand:init(number)
    self.className = "UndoableExampleCommand"
    self.number = number
end

function UndoableExampleCommand:execute()
    Spring.Echo("Setting value: " .. tostring(self.number))
    self.old = value
    value = self.number
end

function UndoableExampleCommand:unexecute()
    Spring.Echo("Reverting to: " .. tostring(self.old))
    value = self.old
end
