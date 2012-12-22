WidgetAddAreaCommand = AbstractCommand:extends{}

function WidgetAddAreaCommand:init(id, value)
    self.className = "WidgetAddAreaCommand"
    self.id = id
    self.value = value
end

function WidgetAddAreaCommand:execute()
    SCEN_EDIT.model.areaManager:addArea(self.value, self.id)
end
