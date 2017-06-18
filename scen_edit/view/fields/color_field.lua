SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

ColorField = Field:extends{}

function ColorField:Update(source)
    self.imValue.color = self.value
    self.imValue:Invalidate()

    if self.colorPicker and source ~= self.colorPicker then
        self.colorPicker:Set("rgbColor", self.value)
        self.colorPicker:Set("hsvColor", self.value)
    end
--     if source ~= self.colorbars then
--         self.colorbars:SetColor(self.value)
--     end
end

function ColorField:init(field)
    self.width  = 200
    self.height = 30
    self.value  = {1, 1, 1, 1}
    self:super('init', field)
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
                self.originalValue = SB.deepcopy(self.value)
--                 self.button:Hide()
                self.colorPicker = ColorFieldPickerWindow(self.originalValue)
                self.colorPicker.field = self
            end
        },
        children = {
            self.imValue,
            self.lblTitle,
        },
    }
    self.components = {
        self.button,
    }
end
