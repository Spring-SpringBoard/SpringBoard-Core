RmlUiCommandWindow = LCS.class{}

function RmlUiCommandWindow:init(model)
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/command_window.rml')
    self.model = model or CommandWindowModel()
end

function RmlUiCommandWindow:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    self:BindEvents()
    self.model:AddListener(self)
    self.model:Initialize()
    Log.Notice("Command Window initialized (RmlUi)")
    return true
end

function RmlUiCommandWindow:BindEvents()
    local btnUndo = self.document:GetElementById("btn-undo")
    if btnUndo then
        btnUndo:AddEventListener("click", function()
            self.model:ExecuteUndo()
        end)
    end

    local btnRedo = self.document:GetElementById("btn-redo")
    if btnRedo then
        btnRedo:AddEventListener("click", function()
            self.model:ExecuteRedo()
        end)
    end

    local btnClear = self.document:GetElementById("btn-clear-history")
    if btnClear then
        btnClear:AddEventListener("click", function()
            self.model:ExecuteClearHistory()
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

-- UI update callbacks from model
function RmlUiCommandWindow:OnPushCommand(id, display)
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

function RmlUiCommandWindow:OnUndoCommand(cmdId)
    local cmdItem = self.document:GetElementById("cmd-" .. cmdId)
    if cmdItem then
        cmdItem:AddClass("undone")
    end
end

function RmlUiCommandWindow:OnRedoCommand(cmdId)
    local cmdItem = self.document:GetElementById("cmd-" .. cmdId)
    if cmdItem then
        cmdItem:RemoveClass("undone")
    end
end

function RmlUiCommandWindow:OnRemoveFirstUndo(cmdId)
    local cmdItem = self.document:GetElementById("cmd-" .. cmdId)
    if cmdItem then
        cmdItem.parent_node:RemoveChild(cmdItem)
    end
end

function RmlUiCommandWindow:OnRemoveFirstRedo(cmdId)
    local cmdItem = self.document:GetElementById("cmd-" .. cmdId)
    if cmdItem then
        cmdItem.parent_node:RemoveChild(cmdItem)
    end
end
