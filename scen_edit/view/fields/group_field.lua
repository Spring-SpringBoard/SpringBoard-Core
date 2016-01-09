SCEN_EDIT.Include(SCEN_EDIT_VIEW_FIELDS_DIR .. "field.lua")

GroupField = Field:extends{}
local _GROUP_INDEX = 0

function GroupField:init(fields)
    self:super('init', {})
    _GROUP_INDEX = _GROUP_INDEX + 1
    self.name = "_groupField" .. tostring(_GROUP_INDEX)
    self.fields = fields
    self.components = {
    }
end

function GroupField:Added()
    local groupX = 0
    for i, field in pairs(self.fields) do
        self.ev:_AddField(field)
        for _, comp in pairs(field.components) do
            comp.x = groupX
            self.ctrl:AddChild(comp)
        end
        groupX = groupX + field.width + 10
        field:Added()
        field.visible = true
    end
end

function GroupField:_HackSetInvisibleFields(fields)
    for _, field in pairs(self.fields) do
        local visible = field.visible
        local found = false
        for _, name in pairs(fields) do
            if name == field.name and visible then
                field.visible = false
                for _, comp in pairs(field.components) do
                    self.ctrl:RemoveChild(comp)
                end
            end
        end
        if not visible and not found then
            field.visible = true
            for _, comp in pairs(field.components) do
                self.ctrl:AddChild(comp)
                if comp.hidden then
                    comp:Hide()
                end
            end
        end
    end
end