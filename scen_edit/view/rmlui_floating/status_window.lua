RmlUiStatusWindow = LCS.class{}

function RmlUiStatusWindow:init(model)
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/status_window.rml')
    self.model = model or StatusWindowModel()
end

function RmlUiStatusWindow:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    self.model:Initialize()
    Log.Notice("Status Window initialized (RmlUi)")
    return true
end

function RmlUiStatusWindow:Show()
    self.document:Show()
end

function RmlUiStatusWindow:Hide()
    self.document:Hide()
end

function RmlUiStatusWindow:Update()
    self.model:Update()
    self:UpdateUI()
end

function RmlUiStatusWindow:UpdateUI()
    self.document:GetElementById("status-position").inner_rml = self.model:GetStatusText()
    self.document:GetElementById("status-memory").inner_rml = self.model:GetMemoryText()
    self.document:GetElementById("status-version").inner_rml = self.model:GetVersionText()
end
