SB.Include(Path.Join(SB.DIRS.SRC, 'view/dialog/dialog.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'view/floating/top_left_menu_model.lua'))

TopLeftMenu = LCS.class{}

function TopLeftMenu:init()
    self.y = 35
    self.item_h = 35
    self.item_fontSize = 16
    self.item_padding = 7

    self.children = {}
    self.model = TopLeftMenuModel()

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
                        self.model:Exit()
                    end,
                })
            end
        }
    })
end

function TopLeftMenu:AddLobbyButton()
    if not self.model:IsLuaMenuAvailable() then
        return
    end

    self.model:DisableLobbyButton()
    self:AddTopRightButton({
        caption = "Menu",
        OnClick = {
            function()
                self.model:ShowMenu()
            end
        }
    })
end

function TopLeftMenu:AddUploadLogButton()
    if not self.model:IsConnectorAvailable() then
        return
    end

    self.btnUpload = self:AddTopRightButton({
        caption = "Upload Log",
        tooltip = 'Upload the entire log. Do this if you want to report bugs.',
        OnClick = {
            function()
                Dialog({
                    message = "Do you want to upload your log to http://logs.springrts.com ?" ..
                              "\nAll data will be public.",
                    ConfirmDialog = function()
                        self.model:UploadLog(
                            function()
                                self.btnUpload:SetCaption('Uploading...')
                                self.btnUpload:SetEnabled(false)
                            end,
                            function(success, msg)
                                self.btnUpload:SetCaption('Upload Log')
                                self.btnUpload:SetEnabled(true)
                            end
                        )
                    end,
                })
            end
        }
    })
end

function TopLeftMenu:AddOpenDataDirButton()
    if not self.model:IsConnectorAvailable() then
        return
    end

    self:AddTopRightButton({
        caption = "Data dir",
        tooltip = 'Open the springboard data directory in the OS file explorer.',
        OnClick = {
            function()
                self.model:OpenDataDir()
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

    if self.model:IsConnectorAvailable() then
        self.btnOpenProject = self:AddTopRightButton({
            caption = "Open project",
            tooltip = 'Open current project',
            OnClick = {
                function()
                    self.model:OpenProject()
                end
            },
        })
    end

    self:Update()
end

function TopLeftMenu:Update()
    if not self.model:Update() then
        return
    end

    -- Update project label
    local projectCaption = self.model:GetProjectCaption()
    if self.lblProject.caption ~= projectCaption then
        self.lblProject:SetCaption(projectCaption)
    end

    -- Update open project button
    if self.btnOpenProject then
        self.btnOpenProject:SetEnabled(self.model:HasProjectPath())
    end
end

