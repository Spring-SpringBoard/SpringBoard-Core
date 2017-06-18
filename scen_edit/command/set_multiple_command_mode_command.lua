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
