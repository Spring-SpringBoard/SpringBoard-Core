SB.Include(Path.Join(SB.DIRS.SRC, 'view/floating/command_window_model.lua'))

RmlUiCommandWindow = LCS.class{}

function RmlUiCommandWindow:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/command_window.rml')
    self.model = CommandWindowModel()

    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    assert(self.document, "Command Window failed to load document")

    -- Cache elements
    self.elements = {
        btnUndo = self.document:GetElementById("btn-undo"),
        btnRedo = self.document:GetElementById("btn-redo"),
        btnClear = self.document:GetElementById("btn-clear-history"),
        commandList = self.document:GetElementById("command-list"),
    }

    for name, element in pairs(self.elements) do
        assert(element, "Command Window missing element: " .. name)
    end

    -- Register view callbacks with model
    self.model.onPushCommand = function(id, display)
        self:OnPushCommand(id, display)
    end
    self.model.onUndoCommand = function(id)
        self:OnUndoCommand(id)
    end
    self.model.onRedoCommand = function(id)
        self:OnRedoCommand(id)
    end
    self.model.onRemoveFirstUndo = function(removedCount)
        self:OnRemoveFirstUndo(removedCount)
    end
    self.model.onRemoveFirstRedo = function(count)
        self:OnRemoveFirstRedo(count)
    end
    self.model.onClearUndoStack = function()
        self:OnClearUndoStack()
    end
    self.model.onClearRedoStack = function()
        self:OnClearRedoStack()
    end
    self.model.onButtonStateChanged = function(canUndo, canRedo, canClear)
        self:UpdateButtonStates(canUndo, canRedo, canClear)
    end

    self:BindEvents()

    -- Clear any existing command history that was created before this window
    -- The model tracks history but we need to sync the DOM
    self.elements.commandList.inner_rml = ""

    self:UpdateButtonStates(false, false, false)
end

function RmlUiCommandWindow:BindEvents()
    self.elements.btnUndo:AddEventListener("click", function()
        self.model:ExecuteUndo()
    end)

    self.elements.btnRedo:AddEventListener("click", function()
        self.model:ExecuteRedo()
    end)

    self.elements.btnClear:AddEventListener("click", function()
        self.model:ExecuteClearHistory()
    end)
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

function RmlUiCommandWindow:OnPushCommand(id, display)
    local commandItem = string.format(
        '<div class="command-item" id="cmd-%d">%d %s</div>',
        id, id, display
    )
    self.elements.commandList.inner_rml = self.elements.commandList.inner_rml .. commandItem
end

function RmlUiCommandWindow:OnUndoCommand(id)
    local cmdElement = self.document:GetElementById("cmd-" .. id)
    if cmdElement then
        cmdElement:SetClass("undone", true)
    end
end

function RmlUiCommandWindow:OnRedoCommand(id)
    local cmdElement = self.document:GetElementById("cmd-" .. id)
    if cmdElement then
        cmdElement:SetClass("undone", false)
    end
end

function RmlUiCommandWindow:OnRemoveFirstUndo(removedCount)
    local cmdElement = self.document:GetElementById("cmd-" .. removedCount)
    if cmdElement then
        local parent = cmdElement.parent_node
        if parent then
            parent:RemoveChild(cmdElement)
        end
    end
end

function RmlUiCommandWindow:OnRemoveFirstRedo(count)
    local cmdElement = self.document:GetElementById("cmd-" .. count)
    if cmdElement then
        local parent = cmdElement.parent_node
        if parent then
            parent:RemoveChild(cmdElement)
        end
    end
end

function RmlUiCommandWindow:OnClearUndoStack()
    -- Just clear the entire command list when clearing undo stack
    self.elements.commandList.inner_rml = ""
end

function RmlUiCommandWindow:OnClearRedoStack()
    -- Clearing redo stack doesn't affect display since undone items stay visible
end

function RmlUiCommandWindow:UpdateButtonStates(canUndo, canRedo, canClear)
    self.elements.btnUndo:SetClass("disabled", not canUndo)
    self.elements.btnRedo:SetClass("disabled", not canRedo)
    self.elements.btnClear:SetClass("disabled", not canClear)
end

function RmlUiCommandWindow:Update()
end
