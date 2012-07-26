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

function StateManager:GetCurrentState()
    return self.currentState
end

function StateManager:SetState(state)
    self.currentState = state
--    Spring.Echo("set state")
end

function StateManager:MousePress(x, y, button)
    return self.currentState:MousePress(x, y, button)
end

function StateManager:MouseMove(x, y, dx, dy, button)
    return self.currentState:MouseMove(x, y, dx, dy, button)
end

function StateManager:MouseRelease(x, y, button)
    return self.currentState:MouseRelease(x, y, button)
end

function StateManager:KeyPress(key, mods, isRepeat, label, unicode)
    return self.currentState:KeyPress(key, mods, isRepeat, label, unicode)
end

function StateManager:GameFrame(frameNum)
    return self.currentState:GameFrame(frameNum)
end

function StateManager:DrawWorld()
    return self.currentState:DrawWorld()
end
