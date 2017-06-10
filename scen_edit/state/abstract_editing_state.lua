AbstractEditingState = AbstractState:extends{}

function AbstractEditingState:init(editorView)
	self.editorView = editorView
end

function AbstractEditingState:enterState()
	-- FIXME: self.editorView should always be available
	if self.editorView then
		self.editorView:_OnEnterState(self)
	end
end

function AbstractEditingState:leaveState()
	-- FIXME: self.editorView should always be available
	if self.editorView then
		self.editorView:_OnLeaveState(self)
	end
end

function AbstractEditingState:KeyPress(key, mods, isRepeat, label, unicode)
    local _, _, button1, button2, button3 = Spring.GetMouseState()
    if button1 or button2 or button3 then
        return false
    end

	if self.keyListener then
		if self.keyListener(key, mods, isRepeat, label, unicode) then
			return true
		end
	end
	-- TODO: make this configurable
    if key == KEYSYMS.Z and mods.ctrl then
        SB.commandManager:undo()
    elseif key == KEYSYMS.Y and mods.ctrl then
        SB.commandManager:redo()
    elseif key == KEYSYMS.S and mods.ctrl and not mods.shift then
        SaveAction():execute()
    elseif key == KEYSYMS.S and mods.ctrl and mods.shift then
        SaveAsAction():execute()
    elseif key == KEYSYMS.O and mods.ctrl then
        LoadAction():execute()
    elseif key == KEYSYMS.E and mods.ctrl then
        ExportAction():execute()
    elseif key == KEYSYMS.I and mods.ctrl then
        ImportAction():execute()
	elseif key == 27 then -- KEYSYMS.ESC
        SB.stateManager:SetState(DefaultState())
    else
        return false
    end
    return true
end

function AbstractEditingState:SetGlobalKeyListener(keyListener)
	self.keyListener = keyListener
end
