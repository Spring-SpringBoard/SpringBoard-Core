WidgetUpdateAreaCommand = AbstractCommand:extends{}

function WidgetUpdateAreaCommand:init(id, mapping)
    self.className = "WidgetUpdateAreaCommand"
    self.id = id
    self.mapping = mapping
end

function WidgetUpdateAreaCommand:execute()
    local area = SCEN_EDIT.model.areaManager:getArea(self.id)
    for k, v in pairs(self.mapping) do
        area[k] = v
    end
end
