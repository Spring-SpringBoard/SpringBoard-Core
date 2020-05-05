SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

FileDialog = Editor:extends {
    caption = "File dialog"
}

function FileDialog:init()
    Editor.init(self)
    self.confirmDialogCallback = nil

    self.fileView = AssetView({
        ctrl = {
            width = "100%",
            y = 30,
            bottom = 130 + SB.conf.B_HEIGHT + 10,
        },
        multiSelect = false,
        dir = self.dir,
        rootDir = self.rootDir,
        OnDblClickItem = {
            function()
                if self:ConfirmDialog() then
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
    self.error = Label:New {
        font = {
            color = { 1, 0, 0, 1 },
        },
        caption = ""
    }
    self:AddControl('error', { self.error })

    local children = {
        Label:New {
            y = 0,
            caption = self.caption,
            font = {
                color = { 0.7, 0.7, 0.7, 1.0 }
            },
        },
        self.fileView:GetControl(),
        ScrollPanel:New {
            x = 0,
            bottom = SB.conf.B_HEIGHT + 10,
            height = 120,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    }

    self:Finalize(children, {
        notMainWindow = true,
        buttons = { "ok", "cancel" },
        x = 500,
        y = 200,
        width = 600,
        height = 650,
    })

    self.fields.fileName:Focus()
--    self:SetDir(self.dir)
end

function FileDialog:setConfirmDialogCallback(func)
    self.confirmDialogCallback = func
end

function FileDialog:getSelectedFilePath()
    return self.fileView.dir .. self.fields.fileName.value
end

function FileDialog:SetDialogError(error)
    if error ~= nil then
        self.error:SetCaption(tostring(error))
    else
        self.error:SetCaption('Unknown error')
    end
end

function FileDialog:ConfirmDialog()
    local path = self:getSelectedFilePath()
    if self.confirmDialogCallback then
        local success, error = self.confirmDialogCallback(path)
        if not success then
            self:SetDialogError(error)
        end
        return success
    end
end

function FileDialog:__ErrorCheck(success, error)
    if not success then
        self:SetDialogError(error)
    end
    return success
end