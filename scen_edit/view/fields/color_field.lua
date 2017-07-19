SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

ColorField = Field:extends{}

function ColorField:Update(source)
    self.imValue.color = self.value
    self.imValue:Invalidate()

    if source ~= self.colorWindow then
        self.colorWindow:Set("rgbColor", self.value)
        self.colorWindow:Set("hsvColor", self.value)
    end
--     if source ~= self.colorbars then
--         self.colorbars:SetColor(self.value)
--     end
end

function ColorField:init(field)
    self.value  = {1, 1, 1, 1}
    if field.expand then
        self.height = 230
        self.width = 450
    else
        self.width = 200
    end

    Field.init(self, field)

    self.lblTitle = Label:New {
        caption = self.title,
        x = 10,
        y = 5,
        autosize = true,
    }
    self.imValue = Image:New {
        color       = {1, 1, 1, 1},
        right       = 5,
        y           = 5,
        height      = self.height - 10,
        width       = self.height - 10,
        keepAspect  = false,
        file        = ":cl:bitmaps/ui/buckets/swatch.png",
        color       = self.value,
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
                self.colorWindow.window:Show()
            end
        },
        children = {
            self.imValue,
            self.lblTitle,
        },
    }

    self.originalValue = SB.deepcopy(self.value)
    self.colorWindow = ColorFieldPickerWindow({
        expand = self.expand,
        value = self.originalValue,
        OnUpdate = {
            function(value)
                self:OnUpdate(value)
            end
        },
        OnStartChange = {
            function(name)
                self.ev:_OnStartChange(self.name)
            end
        },
        OnEndChange = {
            function(name)
                self.ev:_OnEndChange(self.name)
            end
        },
    })
    self.colorWindow.window:Hide()

    if self.expand then
        self.colorWindow.window:SetPos(0, 0, self.width, self.height)
        self.components = {
            self.colorWindow.window
        }
    else
        self.components = {
            self.button,
        }
    end
end

function ColorField:OnUpdate(value)
    self:Set(value, self.colorWindow)
end
