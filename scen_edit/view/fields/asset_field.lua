SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

AssetField = Field:extends{}
AssetField.defaultPaths = {}

function AssetField:Update(source)
    self.lblValue:SetCaption(self:GetCaption())
end

function AssetField:init(field)
    self.width = 200
    self.value = "/"
    Field.init(self, field)

    self.lblValue = Label:New {
        caption = self:GetCaption(),
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
                    --local folderPath = Path.ExtractDir(self.value)
                    --self.AssetFieldWindow = FilePickerWindow(folderPath)
                    --self.AssetFieldWindow.field = self
                    self:MakePickerWindow({
                        rootDir = self.rootDir,
                        path = self:GetPath() or self:GetDefaultPath(),
                        OnSelectItem = {
                            function(item)
                                self:OnSelectItem(item)
                            end
                        }
                    })
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

function AssetField:GetDefaultPath()
    return AssetField.defaultPaths[self.rootDir]
end

function AssetField:SetDefaultPath(path)
    AssetField.defaultPaths[self.rootDir] = path
end

function AssetField:OnSelectItem(item)
    self:Set(item)
    self:SetDefaultPath(self:GetPath())
end

---------------------------------
-- Override
---------------------------------
function AssetField:GetCaption()
    return Path.ExtractFileName(self.value or "")
end

function AssetField:GetPath()
    return self.value
end

function AssetField:MakePickerWindow(tbl)
    return AssetPickerWindow(tbl)
end
