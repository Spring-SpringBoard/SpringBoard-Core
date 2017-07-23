SB_STATE_DIR = SB_DIR .. "state/"

StateManager = LCS.class{}

function StateManager:init()
    SB.Include(SB_STATE_DIR .. 'abstract_state.lua')
    SB.Include(SB_STATE_DIR .. 'abstract_editing_state.lua')
    SB.IncludeDir(SB_STATE_DIR)
    self:SetState(DefaultState())
end

function StateManager:_SafeCall(func)
    succ, result = xpcall(func, function(err)
        Log.Error(debug.traceback(err))
        Log.Error("Error in current state, switching to default state")
        self:SetState(DefaultState())
    end)
    if succ then
        return result
    end
end

function StateManager:GetCurrentState()
    return self.currentState
end

function StateManager:SetState(state)
    if self.currentState ~= nil then
        local oldState = self.currentState
        self.currentState = nil
        oldState:leaveState()
    end
    self.currentState = state
    self.currentState:enterState()
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

function StateManager:Update(frameNum)
    return self:_SafeCall(function()
        return self.currentState:Update()
    end)
end

function StateManager:DrawScreen()
    return self:_SafeCall(function()
        return self.currentState:DrawScreen()
    end)
end

function StateManager:DrawWorld()
    local _, _, _, _, _, outsideSpring = Spring.GetMouseState()
    --FIXME: cursor hacks
    -- First we clear the cursor if it's no longer visible
    -- This allows us to later reset it when it gets back, which prevents a bug
    -- https://github.com/Spring-SpringBoard/SpringBoard-Core/issues/220
    if outsideSpring then
        Spring.SetMouseCursor("dont_use")
    -- This is needed to properly draw the cursor each frame when it is visible
    elseif SB.cursor then
        Spring.AssignMouseCursor(SB.cursor, SB.cursor, false)
        Spring.SetMouseCursor(SB.cursor)
    end

    return self:_SafeCall(function()
        return self.currentState:DrawWorld()
    end)
end

function StateManager:DrawWorldPreUnit()
    return self:_SafeCall(function()
        return self.currentState:DrawWorldPreUnit()
    end)
end
