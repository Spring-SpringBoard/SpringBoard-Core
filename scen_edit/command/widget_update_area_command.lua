WidgetUpdateAreaCommand = AbstractCommand:extends{}

function WidgetUpdateAreaCommand:init(id, mapping)
    self.className = "WidgetUpdateAreaCommand"
    self.id = id
    self.mapping = mapping
end

function WidgetUpdateAreaCommand:execute()
    local area = SB.model.areaManager:getArea(self.id)
    for k, v in pairs(self.mapping) do
        area[k] = v
    end
end
