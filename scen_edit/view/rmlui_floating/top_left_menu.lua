RmlUiTopLeftMenu = LCS.class{}

function RmlUiTopLeftMenu:init(model)
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/top_left_menu.rml')
    self.model = model or TopLeftMenuModel()
end

function RmlUiTopLeftMenu:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    self:BindEvents()
    self.model:AddListener(self)
    self.model:Initialize()
    self:HideUnavailableButtons()
    Log.Notice("Top Left Menu initialized (RmlUi)")
    return true
end

function RmlUiTopLeftMenu:BindEvents()
    self.document:GetElementById("btn-exit"):AddEventListener("click", function()
        self.model:OnExit()
    end)
    self.document:GetElementById("btn-menu"):AddEventListener("click", function()
        self.model:OnMenu()
    end)
    self.document:GetElementById("btn-upload-log"):AddEventListener("click", function()
        self.model:OnUploadLog()
    end)
    self.document:GetElementById("btn-data-dir"):AddEventListener("click", function()
        self.model:OnDataDir()
    end)
    self.document:GetElementById("btn-open-project"):AddEventListener("click", function()
        self.model:OnOpenProject()
    end)
end

function RmlUiTopLeftMenu:HideUnavailableButtons()
    if not self.model:HasLobby() then
        self.document:GetElementById("btn-menu").style.display = "none"
    end

    if not self.model:HasConnector() then
        self.document:GetElementById("btn-upload-log").style.display = "none"
        self.document:GetElementById("btn-data-dir").style.display = "none"
        self.document:GetElementById("btn-open-project").style.display = "none"
    end
end

function RmlUiTopLeftMenu:Show()
    self.document:Show()
end

function RmlUiTopLeftMenu:Hide()
    self.document:Hide()
end

function RmlUiTopLeftMenu:Update()
    self.model:Update()
end

-- Model callbacks
function RmlUiTopLeftMenu:OnProjectChanged(projectDir)
    self.document:GetElementById("project-label").inner_rml = self.model:GetProjectCaption()
end

function RmlUiTopLeftMenu:OnUploadStarted()
    self.document:GetElementById("btn-upload-log").inner_rml = "Uploading..."
end

function RmlUiTopLeftMenu:OnUploadFinished()
    self.document:GetElementById("btn-upload-log").inner_rml = "Upload Log"
end

function RmlUiTopLeftMenu:OnUploadFailed()
    self.document:GetElementById("btn-upload-log").inner_rml = "Upload Log"
end
