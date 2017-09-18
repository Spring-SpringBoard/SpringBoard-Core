--- BooleanField module.

SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

--- BooleanField class.
-- @type BooleanField
BooleanField = Field:extends{}

function BooleanField:Update(source)
    -- if source ~= self.checkBox then
    --     if self.checkBox.checked ~= self.value then
    --         self.checkBox:Toggle()
    --     end
    --     self.checkBox:Invalidate()
    -- end
    if source ~= self.toggleButton then
        self.toggleButton.checked = self.value
        self.toggleButton:Invalidate()
    end
end

--- BooleanField constructor.
-- @function BooleanField()
-- @see field.Field
-- @tparam table opts Table
-- @tparam string opts.title Title.
-- @usage
-- BooleanField({
--     name = "myBooleanField",
--     value = true,
--     title = "My field",
-- })
function BooleanField:init(field)
    self:__SetDefault("width", 200)
    self:__SetDefault("value", false)

    Field.init(self, field)

    -- self.checkBox = Checkbox:New {
    --     caption = self.title or "",
    --     width = self.width,
    --     height = self.height,
    --     checked = self.value,
    --     tooltip = self.tooltip,
    --     OnChange = {
    --         function(_, checked)
    --             self:Set(checked, self.checkBox)
    --         end
    --     }
    -- }
    -- self.components = {
    --     self.checkBox,
    -- }

    self.toggleButton = Button:New {
        caption = self.title or "",
        width = self.width,
        height = self.height,
        checked = self.value,
        tooltip = self.tooltip,
        classname = "toggle_button",
        OnClick = {
            function()
                self:__Toggle()
            end
        }
    }
    self.components = {
        self.toggleButton,
    }
end

function BooleanField:__Toggle()
    self.toggleButton.checked = not self.toggleButton.checked
    self.toggleButton:Invalidate()
    self:Set(self.toggleButton.checked, self.toggleButton)
end
