SCEN_EDIT.Include(SCEN_EDIT_VIEW_FIELDS_DIR .. "field.lua")

FileField = Field:extends{}

function FileField:Update(source)
    local caption = FolderView.ExtractFileName(self, self.value)
    self.lblValue:SetCaption(caption)
end

function FileField:init(field)
    self.width = 200
    self.value = "/"
    Field.init(self, field)

    local caption = FolderView.ExtractFileName(self, self.value)
    self.lblValue = Label:New {
        caption = caption,
        width = "100%",
        right = 5,
        y = 5,
        align = "right",
    }
    self.lblTitle = Label:New {
        caption = self.title,
        x = 10,
        y = 5,
        autosize = true,
    }

    self.button = Button:New {
        caption = "",
        width = self.width,
        height = self.height,
        padding = {0, 0, 0, 0,},
        tooltip = self.tooltip,
        MouseDown = function(obj, x, y, btn, ...) -- Overrides Chili.Button.MouseDown
            if btn == 1 then
                return Chili.Button.MouseDown(obj, x, y, btn, ...)
            end
        end,
        OnClick = {
            function(...)
                if not self.notClick then
                    local folderPath = FolderView.ExtractDir(self, self.value)
                    self.fileFieldWindow = FilePickerWindow(folderPath)
                    self.fileFieldWindow.field = self
                end
            end
        },
        children = { 
            self.lblValue,
            self.lblTitle,
        },
    }

    self.components = {
        self.button,
    }
end