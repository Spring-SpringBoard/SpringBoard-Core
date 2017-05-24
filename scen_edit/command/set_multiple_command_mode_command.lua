SetMultipleCommandModeCommand = AbstractCommand:extends{}

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
end
