SB.Include(Path.Join(SB.DIRS.SRC, 'state/abstract_state.lua'))
SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'state'))

--- StateManager class.
StateManager = LCS.class{}

---------------------------
-- API
---------------------------

--- Get current state.
-- @return current state
function StateManager:GetCurrentState()
    return self.currentState
end

--- Set new state.
-- @tparam abstract_state.AbstractState state New state to set.
-- @usage
-- -- Enter the metal editing state.
-- SB.stateManager:SetState(MetalEditingState(self))
--
-- -- Revert to the default state
-- SB.stateManager:SetState(DefaultState())
function StateManager:SetState(state)
    if self.currentState ~= nil then
        local oldState = self.currentState
        self.currentState = nil
        oldState:leaveState()
    end
    self.currentState = state
    self.currentState:enterState()
end

function StateManager:AddGlobalKeyListener(f)
    table.insert(self.keyListeners, f)
end

function StateManager:RemoveGlobalKeyListener(f)
    for i, keyListener in ipairs(self.keyListeners) do
        if keyListener == f then
            table.remove(self.keyListeners, i)
            return
        end
    end
    Log.Warning(debug.traceback())
    Log.Warning("Trying to remove a listener that doesn't exist")
end
---------------------------
-- end API
---------------------------

---------------------------
-- Internal
---------------------------

function StateManager:init()
    self.keyListeners = {}
    self:SetState(DefaultState())
end

function StateManager:_SafeCall(func)
    local succ, result = xpcall(func, function(err)
        -- we don't need the full log (probably!)
        -- Log.Error(debug.traceback(err))
        Log.Error(debug.traceback(err, 3))
        Log.Error("Error in current state, switching to default state")
        self:SetState(DefaultState())
    end)
    if succ then
        return result
    end
end

---------------------------
-- Callins (internal)
---------------------------
function StateManager:MousePress(mx, my, button)
    return self:_SafeCall(function()
        if self.currentState.MousePress then
            return self.currentState:MousePress(mx, my, button)
        end
    end)
end

function StateManager:MouseMove(mx, my, mdx, mdy, button)
    return self:_SafeCall(function()
        if self.currentState.MouseMove then
            return self.currentState:MouseMove(mx, my, mdx, mdy, button)
        end
    end)
end

function StateManager:MouseRelease(mx, my, button)
    return self:_SafeCall(function()
        if self.currentState.MouseRelease then
            return self.currentState:MouseRelease(mx, my, button)
        end
    end)
end

function StateManager:MouseWheel(up, value)
    return self:_SafeCall(function()
        if self.currentState.MouseWheel then
            return self.currentState:MouseWheel(up, value)
        end
    end)
end

function StateManager:KeyPress(key, mods, isRepeat, label, unicode)
    --Spring.Echo(#self.keyListeners)
    for i = #self.keyListeners, 1, -1 do
        local keyListener = self.keyListeners[i]
        local ret = false
        self:_SafeCall(function()
            if keyListener(key, mods, isRepeat, label, unicode) then
                ret = true
            end
        end)
        if ret then
            return true
        end
    end

    return self:_SafeCall(function()
        if self.currentState.KeyPress then
            return self.currentState:KeyPress(key, mods, isRepeat, label, unicode)
        end
    end)
end

function StateManager:GameFrame(frameNum)
    return self:_SafeCall(function()
        if self.currentState.GameFrame then
            return self.currentState:GameFrame()
        end
    end)
end

function StateManager:Update(frameNum)
    return self:_SafeCall(function()
        if self.currentState.Update then
            return self.currentState:Update()
        end
    end)
end

function StateManager:DrawScreen()
    return self:_SafeCall(function()
        if self.currentState.DrawScreen then
            return self.currentState:DrawScreen()
        end
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
        if self.currentState.DrawWorld then
            return self.currentState:DrawWorld()
        end
    end)
end

function StateManager:DrawWorldPreUnit()
    return self:_SafeCall(function()
        if self.currentState.DrawWorldPreUnit then
            return self.currentState:DrawWorldPreUnit()
        end
    end)
end
---------------------------
-- End Callins (internal)
---------------------------

---------------------------
-- End Internal
---------------------------
