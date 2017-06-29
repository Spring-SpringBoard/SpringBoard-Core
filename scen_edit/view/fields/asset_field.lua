SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

AssetField = Field:extends{}
AssetField.defaultPaths = {}

function AssetField:Update(source)
    self.lblValue:SetCaption(self:GetCaption())
    if source ~= self.assetWindow then
        self.assetWindow.assetBrowser:SelectAsset(self:GetPath())
    end
end

function AssetField:init(field)
    self.value = "/"
    if field.expand then
        self.height = 200
        self.width = 450
    else
        self.width = 200
    end

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
                    self.assetWindow.window:Show()
                end
            end
        },
        children = {
            self.lblValue,
            self.lblTitle,
        },
    }

    --local folderPath = Path.ExtractDir(self.value)
    --self.AssetFieldWindow = FilePickerWindow(folderPath)
    --self.AssetFieldWindow.field = self
    self.assetWindow = self:MakePickerWindow({
        rootDir = self.rootDir,
        path = self:GetPath() or self:GetDefaultPath(),
        OnSelectItem = {
            function(item)
                self:OnSelectItem(item)
            end
        },
        expand = self.expand,
        itemHeight = self.itemHeight,
        itemWidth = self.itemWidth,
    })
    self.assetWindow.window:Hide()

    if self.expand then
        self.assetWindow.window:SetPos(0, 0, self.width, self.height)
        self.components = {
            self.assetWindow.window
        }
    else
        self.components = {
            self.button,
        }
    end
end

function AssetField:GetDefaultPath()
    return AssetField.defaultPaths[self.rootDir or ""]
end

function AssetField:SetDefaultPath(path)
    AssetField.defaultPaths[self.rootDir or ""] = path
end

function AssetField:OnSelectItem(item)
    self:Set(item, self.assetWindow)
    self:SetDefaultPath(self:GetPath())
end

function AssetField:Serialize()
    return {
        value = self.value,
        path = self:GetPath(),
    }
end

function AssetField:Load(data)
    self:Set(data.value)
    self:SetDefaultPath(data.defaultPath)
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
