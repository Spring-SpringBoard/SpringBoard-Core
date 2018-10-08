UndoableExampleCommand = Command:extends{}
UndoableExampleCommand.className = "UndoableExampleCommand"

local value = 0
function UndoableExampleCommand:init(number)
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
