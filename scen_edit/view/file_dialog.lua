FileDialog = Observable:extends{}

function FileDialog:init(dir, caption, fileTypes)
    self.dir = dir or nil
	self.caption = caption or "File dialog"
    self.confirmDialogCallback = nil
    self.fileTypes = fileTypes
    local buttonPanel = MakeComponentPanel()
    self.fileEditBox = EditBox:New {
        y = 1,
		x = 75,
		right = 0,
        height = "100%",
    }

    local okButton = Button:New {
        height = SB.conf.B_HEIGHT,
        bottom = 5,
        width = "20%",
        right = "22%",
        caption = "OK",
    }

    local cancelButton = Button:New {
        height = SB.conf.B_HEIGHT,
        bottom = 5,
        width = "20%",
		right = 10,
        caption = "Cancel",
    }
    self.fileView = AssetView({
        ctrl = {
            width = "100%",
            y = 10,
            bottom = 90 + SB.conf.B_HEIGHT + 10,
        },
        multiSelect = false,
        dir = self.dir,
        OnDblClickItem = {
            function()
                self:confirmDialog()
                self.window:Dispose()
            end
        },
        OnSelectItem = {
            function(item, selected)
                if selected then
                    local path = item.path
                    local fileName = Path.ExtractFileName(item.path)
                    self.fileEditBox:SetText(fileName)
                end
            end
        }
    })

    self.window = Window:New {
        x = 500,
        y = 200,
        width = 600,
        height = 600,
        parent = screen0,
        caption = self.caption,
        children = {
            self.fileView:GetControl(),
            Control:New {
                x = 1,
                width = "100%",
                height = SB.conf.B_HEIGHT,
                bottom = SB.conf.B_HEIGHT + 20,
                padding = {0, 0, 0, 0},
                children = {
                    Label:New {
						x = 1,
						y = 4,
						valign = "center",
                        width = 65,
                        caption = "File name: ",
						align = "left",
                    },
                    self.fileEditBox,
                },
            },
            okButton,
            cancelButton,
        },
        OnDispose = {
            function()
                SB.stateManager:GetCurrentState():SetGlobalKeyListener()
            end
        }
    }
    if self.fileTypes then
        self.cmbFileTypes = ComboBox:New {
            items = self.fileTypes,
            width = 100,
            height = SB.conf.B_HEIGHT + 10,
            x = 75,
            right = 0,
        }
        local ctrl = Control:New {
            x = 1,
            width = "100%",
            height = SB.conf.B_HEIGHT + 10,
            bottom = 2 * SB.conf.B_HEIGHT + 30,
            padding = {0, 0, 0, 0},
            children = {
                Label:New {
                    x = 1,
                    y = 4,
                    valign = "center",
                    width = 65,
                    caption = "File type: ",
                    align = "left",
                },
                self.cmbFileTypes,
            },
        }
        self.window:AddChild(ctrl)
    end

    okButton.OnClick = {
        function()
            self:confirmDialog()
            self.window:Dispose()
        end
    }
    cancelButton.OnClick = {
        function()
            self.window:Dispose()
        end
    }

    local function keyListener(key)
        if key == Spring.GetKeyCode("esc") then
            self.window:Dispose()
            return true
        elseif key == Spring.GetKeyCode("enter") or key == Spring.GetKeyCode("numpad_enter") then
            self:confirmDialog()
            self.window:Dispose()
            return true
        end
    end

    SB.stateManager:GetCurrentState():SetGlobalKeyListener(keyListener)

    screen0:FocusControl(self.fileEditBox)
--    self:SetDir(self.dir)
end

function FileDialog:setConfirmDialogCallback(func)
    self.confirmDialogCallback = func
end

function FileDialog:getSelectedFilePath()
    local path = self.fileView.dir .. self.fileEditBox.text
    return path
end

function FileDialog:getSelectedFileType()
    if self.cmbFileTypes == nil then
        return nil
    end
    return self.cmbFileTypes.items[self.cmbFileTypes.selected]
end

function FileDialog:confirmDialog()
    local path = self:getSelectedFilePath()
    if self.confirmDialogCallback then
        self.confirmDialogCallback(path)
    end
end
