RmlUiCommandWindow = LCS.class{}

function RmlUiCommandWindow:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/command_window.rml')
    self.count = 0
    self.removedCount = 0
    self.undoCount = 0
end

function RmlUiCommandWindow:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    self:BindEvents()
    Log.Notice("Command Window initialized (RmlUi stub)")
    return true
end

function RmlUiCommandWindow:BindEvents()
    local btnUndo = self.document:GetElementById("btn-undo")
    if btnUndo then
        btnUndo:AddEventListener("click", function()
            self:OnUndo()
        end)
    end

    local btnRedo = self.document:GetElementById("btn-redo")
    if btnRedo then
        btnRedo:AddEventListener("click", function()
            self:OnRedo()
        end)
    end

    local btnClear = self.document:GetElementById("btn-clear-history")
    if btnClear then
        btnClear:AddEventListener("click", function()
            self:OnClearHistory()
        end)
    end
end

function RmlUiCommandWindow:Show()
    if self.document then
        self.document:Show()
    end
end

function RmlUiCommandWindow:Hide()
    if self.document then
        self.document:Hide()
    end
end

function RmlUiCommandWindow:OnUndo()
    Log.Notice("Undo command (not implemented)")
    -- TODO: Execute UndoCommand
end

function RmlUiCommandWindow:OnRedo()
    Log.Notice("Redo command (not implemented)")
    -- TODO: Execute RedoCommand
end

function RmlUiCommandWindow:OnClearHistory()
    Log.Notice("Clear history (not implemented)")
    -- TODO: Execute ClearUndoRedoCommand
end

function RmlUiCommandWindow:PushCommand(display)
    self.count = self.count + 1
    Log.Notice("Command executed: " .. display)
    -- TODO: Add command to list display
end

function RmlUiCommandWindow:OnCommandExecuted(cmdIDs, isUndo, isRedo, display)
    -- Stub for command manager listener
    if isUndo then
        self.undoCount = self.undoCount + 1
    elseif isRedo then
        self.undoCount = self.undoCount - 1
    else
        self:PushCommand(display)
    end
end
