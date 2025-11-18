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
    if self.document then
        self.document:Show()
    end
end

function RmlUiStatusWindow:Hide()
    if self.document then
        self.document:Hide()
    end
end

function RmlUiStatusWindow:Update()
    if not self.document then return end

    self.model:Update()
    self:UpdateUI()
end

function RmlUiStatusWindow:UpdateUI()
    local posElement = self.document:GetElementById("status-position")
    if posElement then
        posElement.inner_rml = self.model:GetStatusText()
    end

    local memElement = self.document:GetElementById("status-memory")
    if memElement then
        memElement.inner_rml = self.model:GetMemoryText()
    end

    local versionElement = self.document:GetElementById("status-version")
    if versionElement then
        versionElement.inner_rml = self.model:GetVersionText()
    end
end
