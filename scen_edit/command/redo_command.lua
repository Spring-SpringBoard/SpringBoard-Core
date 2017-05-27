RedoCommand = Command:extends{}

function RedoCommand:init()
    self.className = "RedoCommand"
end

function RedoCommand:execute()
    SB.commandManager:redo()
end
