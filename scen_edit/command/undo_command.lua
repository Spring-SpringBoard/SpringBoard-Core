UndoCommand = AbstractCommand:extends{}

function UndoCommand:init()
    self.className = "UndoCommand"
end

function UndoCommand:execute()
    SB.commandManager:undo()
end
