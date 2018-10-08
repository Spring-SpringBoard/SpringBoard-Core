RedoCommand = Command:extends{}
RedoCommand.className = "RedoCommand"

local isWidget = Script.GetName() == "LuaUI"
function RedoCommand:init()
    self.isWidget = isWidget
end

function RedoCommand:execute()
    SB.commandManager:redo(self.isWidget)
end
