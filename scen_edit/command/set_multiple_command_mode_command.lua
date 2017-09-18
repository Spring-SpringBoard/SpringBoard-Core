--- SetMultipleCommandModeCommand module

--- SetMultipleCommandModeCommand class
-- Used to group consecutive into a single command on the undo-redo stack. All comamnds that are executed in a single SetMultipleCommandModeCommand block will be merged into a single command.
-- @usage
-- -- Enter multiple command mode
-- SB.commandManager:execute(SetMultipleCommandModeCommand(true))
-- ...
-- -- Execute other commands...
-- ...
-- -- Leave multiple comamnd mode (creates only one command on the undo/redo stack)
-- SB.commandManager:execute(SetMultipleCommandModeCommand(false))
SetMultipleCommandModeCommand = Command:extends{}

function SetMultipleCommandModeCommand:init(state)
    self.className = "SetMultipleCommandModeCommand"
    self.state = state
end

function SetMultipleCommandModeCommand:execute()
    if self.state then
        SB.commandManager:enterMultipleCommandMode()
    else
        SB.commandManager:leaveMultipleCommandMode()
    end
    -- Also set the multiple command mode in unsynced
    if Script.GetName() ~= "LuaUI" then
        SB.commandManager:execute(self, true)
    end
end
