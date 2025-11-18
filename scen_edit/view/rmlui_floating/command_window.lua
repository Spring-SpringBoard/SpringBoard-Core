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
    self.document:GetElementById("btn-undo"):AddEventListener("click", function()
        self.model:ExecuteUndo()
    end)
    self.document:GetElementById("btn-redo"):AddEventListener("click", function()
        self.model:ExecuteRedo()
    end)
    self.document:GetElementById("btn-clear-history"):AddEventListener("click", function()
        self.model:ExecuteClearHistory()
    end)
end

function RmlUiCommandWindow:Show()
    self.document:Show()
end

function RmlUiCommandWindow:Hide()
    self.document:Hide()
end

-- UI update callbacks from model
function RmlUiCommandWindow:OnPushCommand(id, display)
    local commandList = self.document:GetElementById("command-list")
    local itemDiv = self.document:CreateElement("div")
    itemDiv:SetAttribute("class", "command-item")
    itemDiv:SetAttribute("id", "cmd-" .. id)
    itemDiv.inner_rml = tostring(id) .. " " .. display
    commandList:AppendChild(itemDiv)
    commandList.scroll_top = commandList.scroll_height
end

function RmlUiCommandWindow:OnUndoCommand(cmdId)
    self.document:GetElementById("cmd-" .. cmdId):AddClass("undone")
end

function RmlUiCommandWindow:OnRedoCommand(cmdId)
    self.document:GetElementById("cmd-" .. cmdId):RemoveClass("undone")
end

function RmlUiCommandWindow:OnRemoveFirstUndo(cmdId)
    local cmdItem = self.document:GetElementById("cmd-" .. cmdId)
    cmdItem.parent_node:RemoveChild(cmdItem)
end

function RmlUiCommandWindow:OnRemoveFirstRedo(cmdId)
    local cmdItem = self.document:GetElementById("cmd-" .. cmdId)
    cmdItem.parent_node:RemoveChild(cmdItem)
end
