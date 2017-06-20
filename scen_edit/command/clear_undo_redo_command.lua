ClearUndoRedoCommand = Command:extends{}
ClearUndoRedoCommand.className = "ClearUndoRedoCommand"

function ClearUndoRedoCommand:init()
    self.className = "ClearUndoRedoCommand"
end

function ClearUndoRedoCommand:execute()
    SB.commandManager:clearUndoRedoStack()
end
