TopLeftMenu = LCS.class{}

function TopLeftMenu:init(model)
    self.model = model or TopLeftMenuModel()
    self.y = 35
    self.item_h = 35
    self.item_fontSize = 16
    self.item_padding = 7
    self.children = {}

    self:AddExitButton()
    if self.model:HasLobby() then
        self:AddLobbyButton()
    end
    if self.model:HasConnector() then
        self:AddUploadLogButton()
        self:AddOpenDataDirButton()
    end
    self:AddProjectMenu()

    self.model:AddListener(self)
    self.model:Initialize()
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
                self.model:OnExit()
            end
        }
    })
end

function TopLeftMenu:AddLobbyButton()
    self:AddTopRightButton({
        caption = "Menu",
        OnClick = {
            function()
                self.model:OnMenu()
            end
        }
    })
end

function TopLeftMenu:AddUploadLogButton()
    self.btnUpload = self:AddTopRightButton({
        caption = "Upload Log",
        tooltip = 'Upload the entire log. Do this if you want to report bugs.',
        OnClick = {
            function()
                self.model:OnUploadLog()
            end
        }
    })
end

function TopLeftMenu:AddOpenDataDirButton()
    self:AddTopRightButton({
        caption = "Data dir",
        tooltip = 'Open the springboard data directory in the OS file explorer.',
        OnClick = {
            function()
                self.model:OnDataDir()
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

    if self.model:HasConnector() then
        self.btnOpenProject = self:AddTopRightButton({
            caption = "Open project",
            tooltip = 'Open current project',
            OnClick = {
                function()
                    self.model:OnOpenProject()
                end
            },
        })
    end
end

function TopLeftMenu:Update()
    self.model:Update()
end

-- Model callbacks
function TopLeftMenu:OnProjectChanged(projectDir)
    local projectCaption = self.model:GetProjectCaption()
    if self.btnOpenProject then
        self.btnOpenProject:SetEnabled(projectDir and projectDir ~= -1)
    end
    if self.lblProject.caption ~= projectCaption then
        self.lblProject:SetCaption(projectCaption)
    end
end

function TopLeftMenu:OnUploadStarted()
    self.btnUpload:SetCaption('Uploading...')
    self.btnUpload:SetEnabled(false)
end

function TopLeftMenu:OnUploadFinished()
    self.btnUpload:SetEnabled(true)
    self.btnUpload:SetCaption('Upload Log')
end

function TopLeftMenu:OnUploadFailed()
    self.btnUpload:SetEnabled(true)
    self.btnUpload:SetCaption('Upload Log')
end
