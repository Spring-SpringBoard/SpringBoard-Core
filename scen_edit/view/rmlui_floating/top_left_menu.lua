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
    local btnExit = self.document:GetElementById("btn-exit")
    if btnExit then
        btnExit:AddEventListener("click", function()
            self.model:OnExit()
        end)
    end

    local btnMenu = self.document:GetElementById("btn-menu")
    if btnMenu then
        btnMenu:AddEventListener("click", function()
            self.model:OnMenu()
        end)
    end

    local btnUploadLog = self.document:GetElementById("btn-upload-log")
    if btnUploadLog then
        btnUploadLog:AddEventListener("click", function()
            self.model:OnUploadLog()
        end)
    end

    local btnDataDir = self.document:GetElementById("btn-data-dir")
    if btnDataDir then
        btnDataDir:AddEventListener("click", function()
            self.model:OnDataDir()
        end)
    end

    local btnOpenProject = self.document:GetElementById("btn-open-project")
    if btnOpenProject then
        btnOpenProject:AddEventListener("click", function()
            self.model:OnOpenProject()
        end)
    end
end

function RmlUiTopLeftMenu:HideUnavailableButtons()
    if not self.model:HasLobby() then
        local btnMenu = self.document:GetElementById("btn-menu")
        if btnMenu then
            btnMenu.style.display = "none"
        end
    end

    if not self.model:HasConnector() then
        local btnUpload = self.document:GetElementById("btn-upload-log")
        if btnUpload then
            btnUpload.style.display = "none"
        end
        local btnDataDir = self.document:GetElementById("btn-data-dir")
        if btnDataDir then
            btnDataDir.style.display = "none"
        end
        local btnOpenProject = self.document:GetElementById("btn-open-project")
        if btnOpenProject then
            btnOpenProject.style.display = "none"
        end
    end
end

function RmlUiTopLeftMenu:Show()
    if self.document then
        self.document:Show()
    end
end

function RmlUiTopLeftMenu:Hide()
    if self.document then
        self.document:Hide()
    end
end

function RmlUiTopLeftMenu:Update()
    self.model:Update()
end

-- Model callbacks
function RmlUiTopLeftMenu:OnProjectChanged(projectDir)
    local projectLabel = self.document:GetElementById("project-label")
    if projectLabel then
        projectLabel.inner_rml = self.model:GetProjectCaption()
    end
end

function RmlUiTopLeftMenu:OnUploadStarted()
    local btnUpload = self.document:GetElementById("btn-upload-log")
    if btnUpload then
        btnUpload.inner_rml = "Uploading..."
    end
end

function RmlUiTopLeftMenu:OnUploadFinished()
    local btnUpload = self.document:GetElementById("btn-upload-log")
    if btnUpload then
        btnUpload.inner_rml = "Upload Log"
    end
end

function RmlUiTopLeftMenu:OnUploadFailed()
    local btnUpload = self.document:GetElementById("btn-upload-log")
    if btnUpload then
        btnUpload.inner_rml = "Upload Log"
    end
end
