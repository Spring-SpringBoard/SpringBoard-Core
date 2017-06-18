RedoCommand = Command:extends{}

local isWidget = Script.GetName() == "LuaUI"
function RedoCommand:init()
    self.className = "RedoCommand"
    self.isWidget = isWidget
end

function RedoCommand:execute()
    SB.commandManager:redo(self.isWidget)
end
