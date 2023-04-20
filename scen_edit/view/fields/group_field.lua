SB.Include(Path.Join(SB.DIRS.SRC, 'view/fields/field.lua'))

--- GroupField module

--- GroupField class. Used to group multiple fields and display them in a single line.
-- @type GroupField

GroupField = Field:extends{}
local _GROUP_INDEX = 0

--- GroupField constructor.
-- @function GroupField()
-- @see field.Field
-- @tparam table fields List of fields
-- @usage
-- GroupField({
--     NumericField({
--         name = "nf1",
--         value = 12,
--         title = "Field1",
--         width = 70,
--     }),
--     NumericField({
--         name = "nf2",
--         value = 7,
--         title = "Field2",
--         width = 70,
--     }),
-- })
function GroupField:init(fields, param)
    Field.init(self, {})

    _GROUP_INDEX = _GROUP_INDEX + 1
	if param then
		self.name = param.name
	else
		self.name = "_groupField" .. tostring(_GROUP_INDEX)
	end
    self.fields = fields
    self.components = {}
    self.autoSize = true
end

function GroupField:Added()
    local groupX = 0
    for _, field in pairs(self.fields) do
        self.ev:_AddField(field)
        for _, comp in pairs(field.components) do
            if self.autoSize then
                if not comp.x then
                    comp.x = 0
                end
                comp.x = comp.x + groupX
            end
            self.ctrl:AddChild(comp)
        end
        if self.autoSize then
            groupX = groupX + field.width + 10
        end
        field:Added()
        field.visible = true
    end
end

function GroupField:_HackSetInvisibleFields(fields)
    for _, field in pairs(self.fields) do
        local found = false
        -- Remove the field if it's in the list of fields to hide
        for _, name in pairs(fields) do
            if name == field.name then
                found = true
                if field.visible then
                    field.visible = false
                    for _, comp in pairs(field.components) do
                        self.ctrl:RemoveChild(comp)
                    end
                end
                break
            end
        end
        -- Show the field if it's not in the list to hide and is invisible
        if not field.visible and not found then
            field.visible = true
            for _, comp in pairs(field.components) do
                local cmpHidden = comp.hidden
                self.ctrl:AddChild(comp)
                if cmpHidden then
                    comp:Hide()
                end
            end
        end
    end
end
