RmlUiTopLeftMenu = LCS.class{}

function RmlUiTopLeftMenu:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/top_left_menu.rml')
    self.projectDir = nil
end

function RmlUiTopLeftMenu:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    self:BindEvents()
    self:Update()
    Log.Notice("Top Left Menu initialized (RmlUi stub)")
    return true
end

function RmlUiTopLeftMenu:BindEvents()
    local btnExit = self.document:GetElementById("btn-exit")
    if btnExit then
        btnExit:AddEventListener("click", function()
            self:OnExit()
        end)
    end

    local btnMenu = self.document:GetElementById("btn-menu")
    if btnMenu then
        btnMenu:AddEventListener("click", function()
            self:OnMenu()
        end)
    end

    local btnUploadLog = self.document:GetElementById("btn-upload-log")
    if btnUploadLog then
        btnUploadLog:AddEventListener("click", function()
            self:OnUploadLog()
        end)
    end

    local btnDataDir = self.document:GetElementById("btn-data-dir")
    if btnDataDir then
        btnDataDir:AddEventListener("click", function()
            self:OnDataDir()
        end)
    end

    local btnOpenProject = self.document:GetElementById("btn-open-project")
    if btnOpenProject then
        btnOpenProject:AddEventListener("click", function()
            self:OnOpenProject()
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

function RmlUiTopLeftMenu:OnExit()
    Log.Notice("Exit requested (not implemented)")
    -- TODO: Show confirmation dialog, then Spring.SendCommands("quit")
end

function RmlUiTopLeftMenu:OnMenu()
    Log.Notice("Show menu (not implemented)")
    -- TODO: Spring.SendLuaMenuMsg("showLobby")
end

function RmlUiTopLeftMenu:OnUploadLog()
    Log.Notice("Upload log (not implemented)")
    -- TODO: Show confirmation dialog, upload log via WG.Connector
end

function RmlUiTopLeftMenu:OnDataDir()
    Log.Notice("Open data directory (not implemented)")
    -- TODO: WG.Connector.Send('OpenFile', {path = SB.DIRS.ROOT_ABS})
end

function RmlUiTopLeftMenu:OnOpenProject()
    Log.Notice("Open project directory (not implemented)")
    -- TODO: Open project dir via WG.Connector
end

function RmlUiTopLeftMenu:Update()
    if not self.document then return end

    local projectLabel = self.document:GetElementById("project-label")
    if projectLabel then
        local projectCaption
        if SB.project and SB.project.path then
            projectCaption = "Project: " .. SB.project.path
        else
            projectCaption = "Project not saved"
        end
        projectLabel.inner_rml = projectCaption
    end
end
