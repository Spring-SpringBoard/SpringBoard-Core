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
