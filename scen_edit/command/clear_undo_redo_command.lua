ClearUndoRedoCommand = Command:extends{}
ClearUndoRedoCommand.className = "ClearUndoRedoCommand"

function ClearUndoRedoCommand:execute()
    SB.commandManager:clearUndoRedoStack()
end
