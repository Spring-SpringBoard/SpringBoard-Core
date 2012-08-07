local SCEN_EDIT_COMMON_DIR = "scen_edit/common/"
local SCEN_EDIT_STATE_DIR = SCEN_EDIT_COMMON_DIR .. "state/"

StateManager = LCS.class{}

function StateManager:init()
    VFS.Include(SCEN_EDIT_STATE_DIR .. 'abstract_state.lua')
    local files = VFS.DirList(SCEN_EDIT_STATE_DIR)
    for i = 1, #files do
        local file = files[i]
        VFS.Include(file)
    end
    self:SetState(DefaultState())
end

function StateManager:_SafeCall(func)
    succ, msg = pcall(func)
    if succ then
        return msg
    else
        Spring.Echo(msg)
        Spring.Echo("Error in current state, switching to default state")
        self:SetState(DefaultState())
    end
end

function StateManager:GetCurrentState()
    return self.currentState
end

function StateManager:SetState(state)
    self.currentState = state
end

function StateManager:MousePress(x, y, button)
    return self:_SafeCall(function() 
        return self.currentState:MousePress(x, y, button)
    end)
end

function StateManager:MouseMove(x, y, dx, dy, button)
    return self:_SafeCall(function() 
        return self.currentState:MouseMove(x, y, dx, dy, button)
    end)
end

function StateManager:MouseRelease(x, y, button)
    return self:_SafeCall(function() 
        return self.currentState:MouseRelease(x, y, button)
    end)
end

function StateManager:MouseWheel(up, value)
    return self:_SafeCall(function() 
        return self.currentState:MouseWheel(up, value)
    end)
end

function StateManager:KeyPress(key, mods, isRepeat, label, unicode)
    return self:_SafeCall(function() 
        return self.currentState:KeyPress(key, mods, isRepeat, label, unicode)
    end)
end

function StateManager:GameFrame(frameNum)
    return self:_SafeCall(function() 
        return self.currentState:GameFrame()
    end)
end

function StateManager:DrawWorld()
    return self:_SafeCall(function() 
        return self.currentState:DrawWorld()
    end)
end

function StateManager:DrawWorldPreUnit()
    return self:_SafeCall(function() 
        return self.currentState:DrawWorldPreUnit()
    end)
end
