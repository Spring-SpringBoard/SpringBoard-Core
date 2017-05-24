SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

ChoiceField = Field:extends{}
function ChoiceField:Update(source)
    if source ~= self.comboBox then
        for i, id in pairs(self.comboBox.ids) do
            if id == self.value then
                self.comboBox:Select(i)
                break
            end
        end
    end
end

function ChoiceField:init(field)
    self.width = 150
    self:super('init', field)
    self.label = Label:New {
        caption = self.title,
        y = 10,
        autosize = true,
    }
    local ids, captions = self.items, self.captions
    if captions == nil then
        captions = self.items
    end
    self.comboBox = ComboBox:New {
        x = 120 - 5,
        width = field.width,
        height = self.height,
        items = captions,
        ids = ids,
    }
    self.comboBox.OnSelect = {
        function(obj, indx)
            local value = self.comboBox.ids[indx]
            self:Set(value, self.comboBox)
        end
    }
    self.value = self.items[1]

    self.components = {
        self.label,
        self.comboBox,
    }
end