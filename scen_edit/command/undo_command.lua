UndoCommand = Command:extends{}
UndoCommand.className = "UndoCommand"

local isWidget = Script.GetName() == "LuaUI"
function UndoCommand:init()
    self.isWidget = isWidget
end

function UndoCommand:execute()
    SB.commandManager:undo(self.isWidget)
end
