SCEN_EDIT.Include(SCEN_EDIT_VIEW_FIELDS_DIR .. "field.lua")

ColorField = Field:extends{}

function ColorField:Update(source)
    self.imValue.color = self.value
    self.imValue:Invalidate()
--     if source ~= self.colorbars then
--         self.colorbars:SetColor(self.value)
--     end
end

function ColorField:init(field)
    self.width = 200
    self.height = 30
    self:super('init', field)
    self.lblTitle = Label:New {
        caption = self.title,
        tooltip = self.tooltip,
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
        color       = {1, 1, 1, 1},
    }
    self.button = Button:New {
        caption = "",
        width = self.width,
        height = self.height,
        padding = {0, 0, 0, 0,},
        MouseDown = function(obj, x, y, btn, ...) -- Overrides Chili.Button.MouseDown
            if btn == 1 then
                return Chili.Button.MouseDown(obj, x, y, btn, ...)
            end
        end,
        OnClick = {
            function(...)
                self.originalValue = SCEN_EDIT.deepcopy(self.value)
--                 self.button:Hide()
                self.colorPicker = ColorFieldPickerWindow(self.originalValue)
                self.colorPicker.field = self
                self.colorPicker.window.OnDispose = {
                    function()
--                             self.button:Show()
                    end,
                }
--                     self.ev:_OnStartChange(self.name)
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