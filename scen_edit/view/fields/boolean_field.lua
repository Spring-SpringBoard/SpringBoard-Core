SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

BooleanField = Field:extends{}
function BooleanField:Update(source)
    if source ~= self.checkBox then
        if self.checkBox.checked ~= self.value then
            self.checkBox:Toggle()
        end
        self.checkBox:Invalidate()
    end
end

function BooleanField:init(field)
    self.width = 200
    self:super('init', field)
    self.checkBox = Checkbox:New {
        caption = self.title,
        x = 0,
        width = self.width,
        height = self.height,
        checked = self.value,
        tooltip = self.tooltip,
    }
    self.checkBox.OnChange = {
        function(obj, checked)
            self:Set(checked, self.checkBox)
        end
    }

    self.components = {
        self.checkBox,
    }
end