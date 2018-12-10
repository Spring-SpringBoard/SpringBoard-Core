TopRightButtons = LCS.class{}

function TopRightButtons:init()
    self.y = 35
    self.item_h = 50
    self.item_fontSize = 18
    self.item_padding = 5

    self:AddExitButton()
    self:AddLobbyButton()
    self:AddUploadLogButton()
    self:AddOpenProjectButton()
end

function TopRightButtons:AddTopRightButton(tbl)
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
    return btn
end

function TopRightButtons:AddExitButton()
    self:AddTopRightButton({
        caption = "Exit",
        OnClick = {
            function()
                Spring.SendCommands("quit", "quitforce")
            end
        }
    })
end

function TopRightButtons:AddLobbyButton()
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

function TopRightButtons:AddUploadLogButton()
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
        tooltip = 'Upload the entire log (all data will be public). Do this if you want to report bugs.',
        OnClick = {
            function()
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
        }
    })
end

function TopRightButtons:AddOpenProjectButton()
    if not WG.Connector and SB_ROOT_ABS then
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

