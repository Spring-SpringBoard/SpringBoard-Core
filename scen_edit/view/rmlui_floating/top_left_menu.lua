SB.Include(Path.Join(SB.DIRS.SRC, 'view/dialog/dialog.lua'))

RmlUiTopLeftMenu = LCS.class{}

function RmlUiTopLeftMenu:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/top_left_menu.rml')
    self.projectDir = -1  -- initial invalid value to enforce updating the caption
end

function RmlUiTopLeftMenu:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    self:BindEvents()
    self:SetupUploadLog()
    self:CheckLobbyAvailability()
    self:HideUnavailableButtons()
    self:Update()
    Log.Notice("Top Left Menu initialized (RmlUi)")
    return true
end

function RmlUiTopLeftMenu:SetupUploadLog()
    if not WG.Connector then
        return
    end

    WG.Connector.Register('UploadLogFinished', function(command)
        local url = command.url
        local txt = 'Log uploaded to: ' .. tostring(url) .. " (Copied to clipboard)"
        Log.Notice(txt)
        WG.Chotify:Post({
            body = txt,
            title = "Log Uploaded",
            time = 15,
        })
        Spring.SetClipboard(url)
        local btnUpload = self.document:GetElementById("btn-upload-log")
        if btnUpload then
            btnUpload.inner_rml = "Upload Log"
            -- TODO: Re-enable button if we add disabled state
        end
    end)

    WG.Connector.Register('UploadLogFailed', function(command)
        local msg = command.msg
        local txt = SB.conf.STATUS_TEXT_DANGER_COLOR .. "Upload failed\b: " .. msg ..  "\n\255\255\255\255Please upload the log manually\b"
        Log.Error(txt)
        WG.Chotify:Post({
            body = txt,
            title = "Log upload failed",
            time = 20,
        })
        local btnUpload = self.document:GetElementById("btn-upload-log")
        if btnUpload then
            btnUpload.inner_rml = "Upload Log"
            -- TODO: Re-enable button if we add disabled state
        end
    end)
end

function RmlUiTopLeftMenu:CheckLobbyAvailability()
    local luaMenu = Spring.GetMenuName and Spring.SendLuaMenuMsg and Spring.GetMenuName()
    if luaMenu and luaMenu ~= "" then
        Spring.SendLuaMenuMsg("disableLobbyButton")
    else
        -- Hide menu button if not available
        local btnMenu = self.document:GetElementById("btn-menu")
        if btnMenu then
            btnMenu.style.display = "none"
        end
    end
end

function RmlUiTopLeftMenu:HideUnavailableButtons()
    if not WG.Connector then
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
    Dialog({
        message = "Are you sure you want to exit?",
        ConfirmDialog = function()
            Spring.SendCommands("quit", "quitforce")
        end,
    })
end

function RmlUiTopLeftMenu:OnMenu()
    Spring.SendLuaMenuMsg("showLobby")
end

function RmlUiTopLeftMenu:OnUploadLog()
    Dialog({
        message = "Do you want to upload your log to http://logs.springrts.com ?" ..
                  "\nAll data will be public.",
        ConfirmDialog = function()
            self:UploadLog()
        end,
    })
end

function RmlUiTopLeftMenu:UploadLog()
    local btnUpload = self.document:GetElementById("btn-upload-log")
    if btnUpload then
        btnUpload.inner_rml = "Uploading..."
        -- TODO: Disable button if we add disabled state
    end
    WG.Connector.Send('UploadLog', {
        path = SB.DIRS.ROOT_ABS
    })
end

function RmlUiTopLeftMenu:OnDataDir()
    WG.Connector.Send('OpenFile', {
        path = SB.DIRS.ROOT_ABS
    })
end

function RmlUiTopLeftMenu:OnOpenProject()
    if self.projectDir == nil or self.projectDir == -1 then
        return
    end
    WG.Connector.Send('OpenFile', {
        path = Path.Join(SB.DIRS.WRITE_PATH, self.projectDir)
    })
end

function RmlUiTopLeftMenu:Update()
    if not self.document then return end

    if SB.project.path == self.projectDir then
        return
    end
    self.projectDir = SB.project.path

    local projectLabel = self.document:GetElementById("project-label")
    if projectLabel then
        local projectCaption
        if self.projectDir then
            projectCaption = "Project: " .. self.projectDir
        else
            projectCaption = "Project not saved"
        end
        projectLabel.inner_rml = projectCaption
    end
end
