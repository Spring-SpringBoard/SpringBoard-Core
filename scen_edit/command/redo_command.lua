RedoCommand = Command:extends{}
RedoCommand.className = "RedoCommand"

function RedoCommand:execute()
    SB.commandManager:redo()
end
