UndoCommand = Command:extends{}
UndoCommand.className = "UndoCommand"

function UndoCommand:execute()
    SB.commandManager:undo()
end
