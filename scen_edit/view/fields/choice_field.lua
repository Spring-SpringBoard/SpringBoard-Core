--- ChoiceField module.
SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

--- ChoiceField class.
-- @type ChoiceField
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

--- ChoiceField constructor.
-- @function ChoiceField()
-- @see field.Field
-- @tparam table opts Table
-- @tparam string opts.title Title.
-- @tparam table opts.items List of items.
-- @tparam[opt=items] table opts.captions List of captions (one per item).
-- @usage
-- ChoiceField({
--     name = "choiceField",
--     items = {1, 2, 3},
--     captions = {"Blue", "Green", "Yellow"},
-- })
function ChoiceField:init(field)
    self:__SetDefault("width", 150)

    Field.init(self, field)

    if self.title then
        self.label = Label:New {
            caption = self.title,
            y = 10,
            autosize = true,
        }
    end

    local ids, captions = self.items, self.captions
    if captions == nil then
        captions = self.items
        self.captions = self.items
    end
    self:__SetDefault("value", ids[1])

    local comboBoxX = 0
    if self.label then
        comboBoxX = self.label.width + 5
    end
    self.comboBox = ComboBox:New {
        x = comboBoxX,
        width = self.width - comboBoxX,
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
    self:Update(self.value)

    if self.title then
        self.components = {
            self.label,
            self.comboBox,
        }
    else
        self.components = {
            self.comboBox,
        }
    end
end

function ChoiceField:GetCaption(id)
    id = id or self.value
    return self.captions[Table.GetIndex(self.items, id)]
end
