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
    SB.commandManager:addListener(self)
    Log.Notice("Command Window initialized (RmlUi)")
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
    SB.commandManager:execute(UndoCommand())
end

function RmlUiCommandWindow:OnRedo()
    SB.commandManager:execute(RedoCommand())
end

function RmlUiCommandWindow:OnClearHistory()
    SB.commandManager:execute(ClearUndoRedoCommand())
end

function RmlUiCommandWindow:PushCommand(display)
    self.count = self.count + 1
    local id = self.count
    Log.Debug("do", id)

    local commandList = self.document:GetElementById("command-list")
    if commandList then
        local itemDiv = self.document:CreateElement("div")
        itemDiv:SetAttribute("class", "command-item")
        itemDiv:SetAttribute("id", "cmd-" .. id)
        itemDiv.inner_rml = tostring(id) .. " " .. display
        commandList:AppendChild(itemDiv)

        -- Scroll to bottom
        commandList.scroll_top = commandList.scroll_height
    end
end

function RmlUiCommandWindow:UndoCommand()
    Log.Debug("undo", self.count - self.undoCount)
    local cmdItem = self.document:GetElementById("cmd-" .. (self.count - self.undoCount))
    if cmdItem then
        cmdItem:AddClass("undone")
    end
    self.undoCount = self.undoCount + 1
end

function RmlUiCommandWindow:RedoCommand()
    Log.Debug("redo", self.count - self.undoCount + 1)
    local cmdItem = self.document:GetElementById("cmd-" .. (self.count - self.undoCount + 1))
    if cmdItem then
        cmdItem:RemoveClass("undone")
    end
    self.undoCount = self.undoCount - 1
end

function RmlUiCommandWindow:OnCommandExecuted(cmdIDs, isUndo, isRedo, display)
    if isUndo then
        self:UndoCommand()
    elseif isRedo then
        self:RedoCommand()
    else
        self:PushCommand(display)
    end
end

function RmlUiCommandWindow:OnRemoveFirstUndo()
    Log.Debug("remundo", self.removedCount + 1)
    self.removedCount = self.removedCount + 1
    local cmdItem = self.document:GetElementById("cmd-" .. self.removedCount)
    if cmdItem then
        cmdItem.parent_node:RemoveChild(cmdItem)
    end
end

function RmlUiCommandWindow:OnRemoveFirstRedo()
    Log.Debug(LOG.DEBUG, "remredo")
    local cmdItem = self.document:GetElementById("cmd-" .. self.count)
    if cmdItem then
        cmdItem.parent_node:RemoveChild(cmdItem)
    end
    self.count = self.count - 1
    self.undoCount = self.undoCount - 1
end

function RmlUiCommandWindow:OnClearUndoStack()
    Log.Debug("clearundostack")
    while self.removedCount ~= self.count do
        self:OnRemoveFirstUndo()
    end
    Log.Debug("clearundostackend")
end

function RmlUiCommandWindow:OnClearRedoStack()
    Log.Debug("clearredostack")
    while self.undoCount ~= 0 do
        self:OnRemoveFirstRedo()
    end
    Log.Debug("clearredostackend")
end
