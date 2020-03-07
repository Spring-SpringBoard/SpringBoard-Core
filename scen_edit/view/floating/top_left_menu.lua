SB.Include(Path.Join(SB.DIRS.SRC, 'view/dialog/dialog.lua'))

TopLeftMenu = LCS.class{}

function TopLeftMenu:init()
    self.y = 35
    self.item_h = 35
    self.item_fontSize = 16
    self.item_padding = 7

    self.children = {}

    self:AddExitButton()
    self:AddLobbyButton()
    self:AddUploadLogButton()
    self:AddOpenDataDirButton()
    self:AddProjectMenu()
end

function TopLeftMenu:Show()
    for _, btn in pairs(self.children) do
        btn:Show()
    end
end

function TopLeftMenu:Hide()
    for _, btn in pairs(self.children) do
        btn:Hide()
    end
end

function TopLeftMenu:AddTopRightButton(tbl)
    local btn = Button:New(Table.Merge({
        x = 5,
        y = self.y,
        width = 100,
        height = self.item_h,
        font = {
            size = self.item_fontSize,
            outline = true,
        },
        parent = screen0,
    }, tbl))
    self.y = self.y + self.item_h + self.item_padding
    table.insert(self.children, btn)
    return btn
end

function TopLeftMenu:AddExitButton()
    self:AddTopRightButton({
        caption = "Exit",
        OnClick = {
            function()
                Dialog({
                    message = "Are you sure you want to exit?",
                    ConfirmDialog = function()
                        Spring.SendCommands("quit", "quitforce")
                    end,
                })
            end
        }
    })
end

function TopLeftMenu:AddLobbyButton()
    local luaMenu = Spring.GetMenuName and Spring.SendLuaMenuMsg and Spring.GetMenuName()
    if not luaMenu or luaMenu == "" then
        return
    end

    Spring.SendLuaMenuMsg("disableLobbyButton")
    self:AddTopRightButton({
        caption = "Menu",
        OnClick = {
            function()
                Spring.SendLuaMenuMsg("showLobby")
            end
        }
    })
end

function TopLeftMenu:AddUploadLogButton()
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
        self.btnUpload:SetEnabled(true)
        self.btnUpload:SetCaption('Upload Log')
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
        self.btnUpload:SetEnabled(true)
        self.btnUpload:SetCaption('Upload Log')
    end)

    self.btnUpload = self:AddTopRightButton({
        caption = "Upload Log",
        tooltip = 'Upload the entire log. Do this if you want to report bugs.',
        OnClick = {
            function()
                Dialog({
                    message = "Do you want to upload your log to http://logs.springrts.com ?" ..
                              "\nAll data will be public.",
                    ConfirmDialog = function()
                        self:UploadLog()
                    end,
                })
            end
        }
    })
end

function TopLeftMenu:UploadLog()
    -- FIXME: Chili shouldn't allow this to be invoked if disabled
    if not self.btnUpload.state.enabled then
        return
    end
    self.btnUpload:SetCaption('Uploading...')
    self.btnUpload:SetEnabled(false)
    WG.Connector.Send('UploadLog', {
        path = SB.DIRS.ROOT_ABS
    })
end

function TopLeftMenu:AddOpenDataDirButton()
    if not WG.Connector or not SB.DIRS.ROOT_ABS then
        return
    end

    self:AddTopRightButton({
        caption = "Data dir",
        tooltip = 'Open the springboard data directory in the OS file explorer.',
        OnClick = {
            function()
                WG.Connector.Send('OpenFile', {
                    path = SB.DIRS.ROOT_ABS
                })
            end
        }
    })
end

function TopLeftMenu:AddProjectMenu()
    self.lblProject = Label:New {
        x = 0,
        y = 5,
        autosize = true,
        font = {
            size = 22,
            outline = true,
        },
        parent = screen0,
        caption = "",
    }
    table.insert(self.children, self.lblProject)
    if WG.Connector and SB.DIRS.ROOT_ABS then
        self.btnOpenProject = self:AddTopRightButton({
            caption = "Open project",
            tooltip = 'Open current project',
            OnClick = {
                function()
                    if self.projectDir == nil then
                        return
                    end
                    WG.Connector.Send('OpenFile', {
                        path = Path.Join(SB.DIRS.WRITE_PATH, self.projectDir)
                    })
                end
            },
        })
    end

    -- initial, invalid value to enforce updating the caption
    self.projectDir = -1

    self:Update()
end

function TopLeftMenu:Update()
    if SB.project.path == self.projectDir then
        return
    end
    self.projectDir = SB.project.path

    local projectCaption
    if self.projectDir then
        projectCaption = "Project: " .. self.projectDir
        if self.btnOpenProject ~= nil then
            self.btnOpenProject:SetEnabled(true)
        end
    else
        projectCaption = "Project not saved"
        if self.btnOpenProject ~= nil then
            self.btnOpenProject:SetEnabled(false)
        end
    end
    if self.lblProject.caption ~= projectCaption then
        self.lblProject:SetCaption(projectCaption)
    end
end

