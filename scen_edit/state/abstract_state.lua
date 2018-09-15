--- AbstractState module.

--- AbstractState class.
-- @type AbstractState
-- @see state_manager.StateManager
AbstractState = LCS.class{}

--- AbstractState constructor. Should be invoked from child classes.
-- @tparam editor.Editor editorView Editor to which this state relates to.
function AbstractState:init(editorView)
    self.editorView = editorView
end

function AbstractState:__GetEditor()
    return self.editorView or SB.currentEditor
end

function AbstractState:enterState()
    local editor = self:__GetEditor()
    if editor then
        editor:_OnEnterState(self)
    end
end

function AbstractState:leaveState()
    local editor = self:__GetEditor()
    if editor then
        editor:_OnLeaveState(self)
    end
end

--- KeyPress handling event. Should be invoked from child classes.
function AbstractState:KeyPress(key, mods, isRepeat, label, unicode)
    local _, _, button1, button2, button3 = Spring.GetMouseState()
    if button1 or button2 or button3 then
        return false
    end

    if key == KEYSYMS.ESCAPE and not self:is_A(DefaultState) then
        SB.stateManager:SetState(DefaultState())
        return true
    end

    local editor = self:__GetEditor()
    if editor and not editor.window.__disabled then
        if editor:KeyPress(key, mods, isRepeat, label, unicode) then
            return true
        end
    end

    if key == KEYSYMS.TAB then
        if mods.ctrl then
            if mods.shift then
                SB.view.tabbedWindow:PreviousTab()
                return true
            else
                SB.view.tabbedWindow:NextTab()
                return true
            end
        end
    end

    local action = Action.GetActionsForKeyPress(
        false, key, mods, isRepeat, label, unicode
    )
    if action then
        action:execute()
        return true
    end
    return false
end
