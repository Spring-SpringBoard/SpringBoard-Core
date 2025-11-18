SB.Include(Path.Join(SB.DIRS.SRC, 'view/dialog/dialog.lua'))

TopLeftMenuModel = LCS.class{}

function TopLeftMenuModel:init()
    self.projectDir = -1  -- initial invalid value to enforce updating
    self.listeners = {}
    self.hasConnector = WG.Connector ~= nil
    self.hasLobby = false
end

function TopLeftMenuModel:Initialize()
    self:CheckLobbyAvailability()
    self:SetupUploadLog()
    self:Update()
end

function TopLeftMenuModel:AddListener(listener)
    table.insert(self.listeners, listener)
end

function TopLeftMenuModel:NotifyListeners(event, ...)
    for _, listener in ipairs(self.listeners) do
        if listener[event] then
            listener[event](listener, ...)
        end
    end
end

function TopLeftMenuModel:CheckLobbyAvailability()
    local luaMenu = Spring.GetMenuName and Spring.SendLuaMenuMsg and Spring.GetMenuName()
    if luaMenu and luaMenu ~= "" then
        Spring.SendLuaMenuMsg("disableLobbyButton")
        self.hasLobby = true
    else
        self.hasLobby = false
    end
end

function TopLeftMenuModel:SetupUploadLog()
    if not self.hasConnector then
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
        self:NotifyListeners("OnUploadFinished")
    end)

    WG.Connector.Register('UploadLogFailed', function(command)
        local msg = command.msg
        local txt = SB.conf.STATUS_TEXT_DANGER_COLOR .. "Upload failed\b: " .. msg ..
                    "\n\255\255\255\255Please upload the log manually\b"
        Log.Error(txt)
        WG.Chotify:Post({
            body = txt,
            title = "Log upload failed",
            time = 20,
        })
        self:NotifyListeners("OnUploadFailed")
    end)
end

function TopLeftMenuModel:OnExit()
    Dialog({
        message = "Are you sure you want to exit?",
        ConfirmDialog = function()
            Spring.SendCommands("quit", "quitforce")
        end,
    })
end

function TopLeftMenuModel:OnMenu()
    Spring.SendLuaMenuMsg("showLobby")
end

function TopLeftMenuModel:OnUploadLog()
    Dialog({
        message = "Do you want to upload your log to http://logs.springrts.com ?" ..
                  "\nAll data will be public.",
        ConfirmDialog = function()
            self:UploadLog()
        end,
    })
end

function TopLeftMenuModel:UploadLog()
    self:NotifyListeners("OnUploadStarted")
    WG.Connector.Send('UploadLog', {
        path = SB.DIRS.ROOT_ABS
    })
end

function TopLeftMenuModel:OnDataDir()
    WG.Connector.Send('OpenFile', {
        path = SB.DIRS.ROOT_ABS
    })
end

function TopLeftMenuModel:OnOpenProject()
    if self.projectDir == nil or self.projectDir == -1 then
        return
    end
    WG.Connector.Send('OpenFile', {
        path = Path.Join(SB.DIRS.WRITE_PATH, self.projectDir)
    })
end

function TopLeftMenuModel:Update()
    if SB.project.path == self.projectDir then
        return
    end

    self.projectDir = SB.project.path
    self:NotifyListeners("OnProjectChanged", self.projectDir)
end

function TopLeftMenuModel:GetProjectCaption()
    if self.projectDir and self.projectDir ~= -1 then
        return "Project: " .. self.projectDir
    else
        return "Project not saved"
    end
end

function TopLeftMenuModel:HasConnector()
    return self.hasConnector
end

function TopLeftMenuModel:HasLobby()
    return self.hasLobby
end
