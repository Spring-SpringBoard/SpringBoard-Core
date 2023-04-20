SB.Include(Path.Join(SB.DIRS.SRC, 'view/fields/field.lua'))

--- RemoveButtonField module.


--- RemoveButtonField class.
-- @type RemoveButtonField
RemoveButtonField = Field:extends{}

function RemoveButtonField:Update(source)
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

--- RemoveButtonField constructor.
-- @function RemoveButtonField()
-- @see field.Field
-- @tparam table opts Table
-- @tparam string opts.title Title.
-- @usage
-- RemoveButtonField({
--     name = "myRemoveButtonField",
--     value = true,
--     title = "My field",
-- })
function RemoveButtonField:init(field)
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
        width = self.height,
		height = self.height,
        checked = self.value,
        tooltip = self.tooltip,
        classname = "negative_button",
		padding = {2, 2, 2, 2},
		children = {
			Image:New {
				file = Path.Join(SB.DIRS.IMG, 'cancel.png'),
				height = 21,
				width = 21,
				x = "10%",
				y = "10%"
			},
		},
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

function RemoveButtonField:__Toggle()
    self.toggleButton.checked = not self.toggleButton.checked
    self.toggleButton:Invalidate()
    self:Set(self.toggleButton.checked, self.toggleButton)
end
