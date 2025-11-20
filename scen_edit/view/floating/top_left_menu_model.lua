TopLeftMenuModel = LCS.class{}

function TopLeftMenuModel:init()
    self.projectDir = -1 -- Invalid initial value to force update
    self.uploadInProgress = false

    -- Register Connector callbacks if available
    if WG.Connector then
        self:RegisterConnectorCallbacks()
    end
end

function TopLeftMenuModel:Exit()
    Spring.SendCommands("quit", "quitforce")
end

function TopLeftMenuModel:ShowMenu()
    if Spring.SendLuaMenuMsg then
        Spring.SendLuaMenuMsg("showLobby")
    end
end

function TopLeftMenuModel:UploadLog(onStart, onFinish)
    if not WG.Connector then return false end
    if self.uploadInProgress then return false end

    self.uploadInProgress = true
    if onStart then onStart() end

    WG.Connector.Send('UploadLog', {
        path = SB.DIRS.ROOT_ABS
    })

    -- Store callback for when upload finishes
    self.uploadFinishCallback = onFinish
    return true
end

function TopLeftMenuModel:OpenDataDir()
    if not WG.Connector or not SB.DIRS.ROOT_ABS then return false end

    WG.Connector.Send('OpenFile', {
        path = SB.DIRS.ROOT_ABS
    })
    return true
end

function TopLeftMenuModel:OpenProject()
    if not WG.Connector or not self.projectDir then
        return false
    end

    WG.Connector.Send('OpenFile', {
        path = Path.Join(SB.DIRS.WRITE_PATH, self.projectDir)
    })
    return true
end

function TopLeftMenuModel:GetProjectPath()
    if SB.project and SB.project.path then
        return SB.project.path
    end
    return nil
end

function TopLeftMenuModel:GetProjectCaption()
    local path = self:GetProjectPath()
    if path then
        return "Project: " .. path
    else
        return "Project not saved"
    end
end

function TopLeftMenuModel:HasProjectPath()
    return self:GetProjectPath() ~= nil
end

function TopLeftMenuModel:IsLuaMenuAvailable()
    local luaMenu = Spring.GetMenuName and Spring.SendLuaMenuMsg and Spring.GetMenuName()
    return luaMenu and luaMenu ~= ""
end

function TopLeftMenuModel:IsConnectorAvailable()
    return WG.Connector ~= nil
end

function TopLeftMenuModel:DisableLobbyButton()
    if self:IsLuaMenuAvailable() then
        Spring.SendLuaMenuMsg("disableLobbyButton")
    end
end

function TopLeftMenuModel:RegisterConnectorCallbacks()
    WG.Connector.Register('OpenFileFinished', function(command)
        -- No action needed - file was opened in OS
    end)

    WG.Connector.Register('UploadLogFinished', function(command)
        local url = command.url
        local txt = 'Log uploaded to: ' .. tostring(url) .. " (Copied to clipboard)"
        Log.Notice(txt)

        if WG.Chotify then
            WG.Chotify:Post({
                body = txt,
                title = "Log Uploaded",
                time = 15,
            })
        end

        Spring.SetClipboard(url)
        self.uploadInProgress = false

        if self.uploadFinishCallback then
            self.uploadFinishCallback(true, url)
        end
    end)

    WG.Connector.Register('UploadLogFailed', function(command)
        local msg = command.msg or command.error or "Unknown error"
        local errorMsg = "Unknown error"

        if type(msg) == "table" then
            errorMsg = msg.name or msg.code or msg.message or msg.error or "Error occurred"
        elseif type(msg) == "string" then
            errorMsg = msg
        end

        local txt = "Upload failed: " .. tostring(errorMsg) .. "\nPlease upload the log manually"
        Log.Error(txt)

        if WG.Chotify then
            WG.Chotify:Post({
                body = txt,
                title = "Log upload failed",
                time = 20,
            })
        end

        self.uploadInProgress = false

        if self.uploadFinishCallback then
            self.uploadFinishCallback(false, msg)
        end
    end)
end

function TopLeftMenuModel:Update()
    -- Check if project changed
    local newPath = self:GetProjectPath()
    if newPath ~= self.projectDir then
        self.projectDir = newPath
        return true -- Changed
    end
    return false -- No change
end
