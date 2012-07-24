UndoCommand = LCS.class{}

function UndoCommand:init()
    self.className = "UndoCommand"
end

function UndoCommand:execute()
    SCEN_EDIT.commandManager:undo()
end
