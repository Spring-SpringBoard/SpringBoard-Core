--- RmlUi Base Dialog
--- Base class for all RmlUi dialogs

RmlUiBaseDialog = LCS.class{}

function RmlUiBaseDialog:init(opts)
    self.rmlPath = opts.rmlPath or Path.Join(SB.DIRS.SRC, 'view/rml/dialogs/base_dialog.rml')
    self.title = opts.title or "Dialog"
    self.document = nil
    self.visible = false
    self.onConfirm = opts.onConfirm
    self.onCancel = opts.onCancel
end

function RmlUiBaseDialog:Show()
    if not SB.rmlui or not SB.rmlui.initialized then
        Log.Error("RmlUi not initialized")
        return
    end

    -- Load document
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    if not self.document then
        Log.Error("Failed to load dialog: " .. self.rmlPath)
        return
    end

    -- Set title
    local titleElement = self.document:GetElementById("dialog-title")
    if titleElement then
        titleElement.inner_rml = self.title
    end

    -- Setup event handlers
    self:BindEvents()

    -- Show
    self.document:Show()
    self.visible = true
end

function RmlUiBaseDialog:Hide()
    if self.document then
        self.document:Hide()
        self.visible = false
    end
end

function RmlUiBaseDialog:Close()
    if self.document then
        self.document:Close()
        self.document = nil
        self.visible = false
    end
end

function RmlUiBaseDialog:BindEvents()
    if not self.document then
        return
    end

    -- OK button
    local btnOk = self.document:GetElementById("btn-ok")
    if btnOk then
        btnOk:AddEventListener("click", function()
            self:OnOK()
        end)
    end

    -- Cancel button
    local btnCancel = self.document:GetElementById("btn-cancel")
    if btnCancel then
        btnCancel:AddEventListener("click", function()
            self:OnCancel()
        end)
    end

    -- Close button
    local btnClose = self.document:GetElementById("btn-close")
    if btnClose then
        btnClose:AddEventListener("click", function()
            self:OnCancel()
        end)
    end
end

function RmlUiBaseDialog:OnOK()
    if self.onConfirm then
        local result = self.onConfirm()
        if result ~= false then
            self:Close()
        end
    else
        self:Close()
    end
end

function RmlUiBaseDialog:OnCancel()
    if self.onCancel then
        self.onCancel()
    end
    self:Close()
end
