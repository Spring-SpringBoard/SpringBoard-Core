SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

FileDialog = Editor:extends{}

function FileDialog:init(dir, caption, fileTypes)
    Editor.init(self)

    self.dir = dir or nil
    self.caption = caption or "File dialog"
    self.confirmDialogCallback = nil
    self.fileTypes = fileTypes

    self.fileView = AssetView({
        ctrl = {
            width = "100%",
            y = 10,
            bottom = 130 + SB.conf.B_HEIGHT + 10,
        },
        multiSelect = false,
        dir = self.dir,
        OnDblClickItem = {
            function()
                if self:confirmDialog() then
                    self.window:Dispose()
                end
            end
        },
        OnSelectItem = {
            function(item, selected)
                if selected then
                    self:Set("fileName", Path.ExtractFileName(item.path))
                end
            end
        }
    })

    local fileNameField = {
        name = "fileName",
        title = "File name:",
        width = 250,
    }

    if self.fileTypes then
        self:AddField(GroupField({
            StringField(fileNameField),
            ChoiceField({
                name = "fileType",
                title = "File type:",
                items = self.fileTypes,
                width = 300,
            })
        }))
    else
        fileNameField.width = 500
        self:AddField(StringField(fileNameField))
    end

    local btnOK = Button:New {
        width = '40%',
        x = 1,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        caption = "OK",
        classname = "option_button",
        OnClick = {
            function()
                if self:confirmDialog() then
                    self.window:Dispose()
                end
            end
        }
    }

    local btnCancel = Button:New {
        width = '40%',
        x = '50%',
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        caption = "Cancel",
        classname = "negative_button",
        OnClick = {
            function()
                self.window:Dispose()
            end
        }
    }

    local children = {
        self.fileView:GetControl(),
        ScrollPanel:New {
            x = 0,
            bottom = SB.conf.B_HEIGHT + 10,
            height = 120,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
        btnOK,
        btnCancel,
    }

    local keyListener = function(key)
        if key == Spring.GetKeyCode("esc") then
            self.window:Dispose()
            return true
        elseif key == Spring.GetKeyCode("enter") or key == Spring.GetKeyCode("numpad_enter") then
            if self:confirmDialog() then
                self.window:Dispose()
            end
            return true
        end
    end

    SB.stateManager:AddGlobalKeyListener(keyListener)

    self:Finalize(children, {
        notMainWindow = true,
        noCloseButton = true,
        x = 500,
        y = 200,
        width = 600,
        height = 650,
    })

    self.window.OnDispose = {
        function()
            SB.stateManager:RemoveGlobalKeyListener(keyListener)
        end
    }

    -- FIXME: expose a 'focus' function
    self.fields.fileName:__OnClick()


--    self:SetDir(self.dir)
end

function FileDialog:setConfirmDialogCallback(func)
    self.confirmDialogCallback = func
end

function FileDialog:getSelectedFilePath()
    return self.fileView.dir .. self.fields.fileName.value
end

function FileDialog:confirmDialog()
    local path = self:getSelectedFilePath()
    if self.confirmDialogCallback then
        return self.confirmDialogCallback(path)
    end
end
