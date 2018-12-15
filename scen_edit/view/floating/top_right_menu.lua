SB.Include(Path.Join(SB_VIEW_DIR, "dialog/dialog.lua"))

TopRightMenu = LCS.class{}

function TopRightMenu:init()
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

function TopRightMenu:Show()
    for _, btn in pairs(self.children) do
        btn:Show()
    end
end

function TopRightMenu:Hide()
    for _, btn in pairs(self.children) do
        btn:Hide()
    end
end

function TopRightMenu:AddTopRightButton(tbl)
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

function TopRightMenu:AddExitButton()
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

function TopRightMenu:AddLobbyButton()
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

function TopRightMenu:AddUploadLogButton()
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
                              "\nAll information will be public.",
                    ConfirmDialog = function()
                        self:UploadLog()
                    end,
                })
            end
        }
    })
end

function TopRightMenu:UploadLog()
    -- FIXME: Chili shouldn't allow this to be invoked if disabled
    if not self.btnUpload.state.enabled then
        return
    end
    self.btnUpload:SetCaption('Uploading...')
    self.btnUpload:SetEnabled(false)
    WG.Connector.Send('UploadLog', {
        path = SB_ROOT_ABS
    })
end

function TopRightMenu:AddOpenDataDirButton()
    if not WG.Connector or not SB_ROOT_ABS then
        return
    end

    self:AddTopRightButton({
        caption = "Data dir",
        tooltip = 'Open the springboard data directory in the OS file explorer.',
        OnClick = {
            function()
                WG.Connector.Send('OpenFile', {
                    path = SB_ROOT_ABS
                })
            end
        }
    })
end

function TopRightMenu:AddProjectMenu()
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
    if WG.Connector and SB_ROOT_ABS then
        self.btnOpenProject = self:AddTopRightButton({
            caption = "Open project",
            tooltip = 'Open current project',
            OnClick = {
                function()
                    if self.projectDir == nil then
                        return
                    end
                    WG.Connector.Send('OpenFile', {
                        path = Path.Join(SB_WRITE_PATH, self.projectDir)
                    })
                end
            },
        })
    end

    -- initial, invalid value to enforce updating the caption
    self.projectDir = -1

    self:Update()
end

function TopRightMenu:Update()
    if SB.projectDir == self.projectDir then
        return
    end
    self.projectDir = SB.projectDir

    local projectCaption
    if self.projectDir then
        projectCaption = "Project: " .. self.projectDir
        self.btnOpenProject:SetEnabled(true)
    else
        projectCaption = "Project not saved"
        self.btnOpenProject:SetEnabled(false)
    end
    if self.lblProject.caption ~= projectCaption then
        self.lblProject:SetCaption(projectCaption)
    end
end

