SetMultipleCommandModeCommand = AbstractCommand:extends{}

function SetMultipleCommandModeCommand:init(state)
    self.className = "SetMultipleCommandModeCommand"
    self.state = state
end

function SetMultipleCommandModeCommand:execute()
    if self.state then
        SCEN_EDIT.commandManager:enterMultipleCommandMode()
    else
        SCEN_EDIT.commandManager:leaveMultipleCommandMode()
    end
end
