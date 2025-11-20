SB.Include(Path.Join(SB.DIRS.SRC, 'view/floating/top_left_menu_model.lua'))

RmlUiTopLeftMenu = LCS.class{}

function RmlUiTopLeftMenu:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/top_left_menu.rml')
    self.model = TopLeftMenuModel()

    -- Load document
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)

    -- Cache all UI elements and assert they exist
    self.elements = {
        btnExit = self.document:GetElementById("btn-exit"),
        btnMenu = self.document:GetElementById("btn-menu"),
        btnUploadLog = self.document:GetElementById("btn-upload-log"),
        btnDataDir = self.document:GetElementById("btn-data-dir"),
        btnOpenProject = self.document:GetElementById("btn-open-project"),
        projectLabel = self.document:GetElementById("project-label"),
    }

    -- Assert all required elements exist
    for name, element in pairs(self.elements) do
        assert(element, "Top Left Menu missing element: " .. name)
    end

    self:SetupButtonVisibility()
    self:BindEvents()
    self:Update()
end

function RmlUiTopLeftMenu:SetupButtonVisibility()
    -- Hide buttons that aren't available
    if not self.model:IsLuaMenuAvailable() then
        self.elements.btnMenu:SetAttribute("style", "display: none;")
    end

    if not self.model:IsConnectorAvailable() then
        self.elements.btnUploadLog:SetAttribute("style", "display: none;")
        self.elements.btnDataDir:SetAttribute("style", "display: none;")
        self.elements.btnOpenProject:SetAttribute("style", "display: none;")
    else
        -- Start with Open Project button disabled (will be enabled by Update if project exists)
        self.elements.btnOpenProject:SetPseudoClass("disabled", true)
    end
end

function RmlUiTopLeftMenu:SetUploadButtonState(caption, enabled)
    self.elements.btnUploadLog.inner_rml = caption
    self.elements.btnUploadLog:SetPseudoClass("disabled", not enabled)
end

function RmlUiTopLeftMenu:UpdateProjectDisplay()
    self.elements.projectLabel.inner_rml = self.model:GetProjectCaption()

    if self.model:HasProjectPath() then
        self.elements.btnOpenProject:SetPseudoClass("disabled", false)
    else
        self.elements.btnOpenProject:SetPseudoClass("disabled", true)
    end
end

function RmlUiTopLeftMenu:BindEvents()
    -- Exit button
    self.elements.btnExit:AddEventListener("click", function()
        -- TODO: Add confirmation dialog
        self.model:Exit()
    end)

    -- Menu button
    if self.model:IsLuaMenuAvailable() then
        self.model:DisableLobbyButton()
        self.elements.btnMenu:AddEventListener("click", function()
            self.model:ShowMenu()
        end)
    end

    -- Upload log button
    if self.model:IsConnectorAvailable() then
        self.elements.btnUploadLog:AddEventListener("click", function()
            -- TODO: Add confirmation dialog
            self.model:UploadLog(
                function() self:SetUploadButtonState("Uploading...", false) end,
                function(success) self:SetUploadButtonState("Upload Log", true) end
            )
        end)
    end

    -- Data dir button
    if self.model:IsConnectorAvailable() then
        self.elements.btnDataDir:AddEventListener("click", function()
            self.model:OpenDataDir()
        end)
    end

    -- Open project button
    if self.model:IsConnectorAvailable() then
        self.elements.btnOpenProject:AddEventListener("click", function()
            self.model:OpenProject()
        end)
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
    if self.model:Update() then
        self:UpdateProjectDisplay()
    end
end
