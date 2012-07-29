RedoCommand = AbstractCommand:extends{}

function RedoCommand:init()
    self.className = "RedoCommand"
end

function RedoCommand:execute()
    SCEN_EDIT.commandManager:redo()
end
