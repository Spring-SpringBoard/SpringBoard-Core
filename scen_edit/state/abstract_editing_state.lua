AbstractEditingState = AbstractState:extends{}

function AbstractEditingState:init()
end

function AbstractEditingState:KeyPress(key, mods, isRepeat, label, unicode)
    local _, _, button1, button2, button3 = Spring.GetMouseState()
    if button1 or button2 or button3 then
        return false
    end
    if key == KEYSYMS.Z and mods.ctrl then
        SCEN_EDIT.commandManager:undo()
        return true
    elseif key == KEYSYMS.Y and mods.ctrl then
        SCEN_EDIT.commandManager:redo()
        return true
    end
end
