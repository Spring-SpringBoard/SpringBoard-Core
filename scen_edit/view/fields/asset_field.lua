SB.Include(Path.Join(SB.DIRS.SRC, 'view/fields/field.lua'))

--- AssetField module.


--- AssetField class.
--- @type AssetField.
AssetField = Field:extends{}
AssetField.defaultPaths = {}

function AssetField:Update(source)
    self.lblValue:SetCaption(self:GetCaption())
    if source ~= self.assetWindow and self.assetWindow then
        self.assetWindow.assetBrowser:SelectAsset(self:GetPath())
    end
end

--- AssetField constructor.
-- @function AssetField()
-- @see field.Field
-- @param opts
-- @tparam string opts.title Field title.
-- @tparam[opt=false] boolean opts.expand Whether to expand the field in the Editor or open it with a button.
-- @tparam number opts.height Field height size.
function AssetField:init(field)
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
                self:__MaybeCreatePickerWindow()
                -- TODO: Necessary? Or is it done on create properly?
                self.assetWindow.assetBrowser:SelectAsset(self:GetPath())
                self.assetWindow.window:Show()
            end
        },
        children = {
            self.lblValue,
            self.lblTitle,
        },
    }

    if self.expand then
        self:__MaybeCreatePickerWindow()
        self.components = {
            self.assetWindow.window
        }
    else
        self.components = {
            self.button,
        }
    end
end

function AssetField:__MaybeCreatePickerWindow()
    if self.assetWindow then
        return self.assetWindow
    end
    --local folderPath = Path.ExtractDir(self.value)
    --self.AssetFieldWindow = FilePickerWindow(folderPath)
    --self.AssetFieldWindow.field = self
    self.assetWindow = self:MakePickerWindow({
        name = self.name,
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
    --self.assetWindow.assetBrowser:DeselectAll()

    if self.expand then
        self.assetWindow.window:SetPos(0, 0, self.width, self.height)
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
