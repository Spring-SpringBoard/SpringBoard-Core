SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

AreaField = Field:extends{}

function AreaField:Update(source)
    self.lblValue:SetCaption(self:GetCaption())
end

function AreaField:GetCaption()
    if self.value then
        return "Id=" .. tostring(self.value)
    else
        return ""
    end
end

function AreaField:init(field)
    self.width = 200
    Field.init(self, field)

    local caption = self:GetCaption()
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

    self.OnSelectArea = function(areaId)
        self:Set(areaId, self.button)
    end

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
            function()
                SB.stateManager:SetState(SelectAreaState(self.OnSelectArea))
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
