UndoCommand = Command:extends{}

local isWidget = Script.GetName() == "LuaUI"
function UndoCommand:init()
    self.className = "UndoCommand"
    self.isWidget = isWidget
end

function UndoCommand:execute()
    SB.commandManager:undo(self.isWidget)
end
